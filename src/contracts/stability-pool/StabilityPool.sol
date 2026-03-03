// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {ERC4626} from '@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol';
import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IERC4626} from '@openzeppelin/contracts/interfaces/IERC4626.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {ReentrancyGuard} from '@openzeppelin/contracts/utils/ReentrancyGuard.sol';

import {IStabilityPool} from '@interfaces/IStabilityPool.sol';
import {IStrategyStep} from '@interfaces/IStrategyStep.sol';
import {IEmissionsController} from '@interfaces/IEmissionsController.sol';
import {IOracleRelayer} from '@interfaces/IOracleRelayer.sol';
import {ICollateralAuctionHouse} from '@interfaces/ICollateralAuctionHouse.sol';
import {IProtocolToken} from '@interfaces/tokens/IProtocolToken.sol';
import {ISystemCoin} from '@interfaces/tokens/ISystemCoin.sol';
import {ICoinJoin} from '@interfaces/utils/ICoinJoin.sol';
import {ICollateralJoin} from '@interfaces/utils/ICollateralJoin.sol';
import {ICollateralJoinFactory} from '@interfaces/factories/ICollateralJoinFactory.sol';
import {ISAFEEngine} from '@interfaces/ISAFEEngine.sol';

import {Authorizable} from '@contracts/utils/Authorizable.sol';

import {Math, WAD, RAY, HOUR} from '@libraries/Math.sol';

/**
 * @title StabilityPool
 * @notice ERC4626 vault where users deposit HAI and receive sHAI shares
 * @notice Handles auction covering through configurable strategy step pipelines
 */
contract StabilityPool is ERC4626, Authorizable, ReentrancyGuard, IStabilityPool {
  using SafeERC20 for IERC20;
  using Math for uint256;

  // --- Constants ---

  uint256 internal constant _MAX_SLIPPAGE_BPS = 10_000;

  // --- Data ---

  struct VirtualBalance {
    address token;
    uint256 amount;
  }

  // --- Registry ---

  /// @inheritdoc IStabilityPool
  ISystemCoin public immutable systemCoin;

  /// @inheritdoc IStabilityPool
  IProtocolToken public immutable protocolToken;

  /// @inheritdoc IStabilityPool
  IOracleRelayer public immutable oracleRelayer;

  /// @inheritdoc IStabilityPool
  IEmissionsController public immutable emissionsController;

  /// @inheritdoc IStabilityPool
  ICoinJoin public immutable coinJoin;

  /// @inheritdoc IStabilityPool
  ICollateralJoinFactory public immutable collateralJoinFactory;

  // --- Rewards Data ---

  /// @inheritdoc IStabilityPool
  uint256 public kiteRewardIntegral;

  /// @inheritdoc IStabilityPool
  uint256 public kiteRewardRemaining;

  /// @inheritdoc IStabilityPool
  mapping(address => uint256) public rewardDebt;

  /// @inheritdoc IStabilityPool
  mapping(address => uint256) public claimable;

  // --- Strategy Data ---

  mapping(bytes32 => StepConfig[]) internal _strategySteps;

  mapping(address => bool) internal _safeApprovedAuctionHouse;

  // --- Params ---

  /// @inheritdoc IStabilityPool
  bool public transfersEnabled;

  /// @inheritdoc IStabilityPool
  bool public kiteRewardsActive;

  /// @inheritdoc IStabilityPool
  mapping(address => bool) public isWhitelistedStep;

  /// @inheritdoc IStabilityPool
  mapping(bytes32 => uint16) public collateralSlippageBps;

  /// @inheritdoc IStabilityPool
  mapping(bytes32 => uint16) public stepTypeSlippageBps;

  /// @inheritdoc IStabilityPool
  uint256 public lastInternalCoinSweepTime;

  // --- Init ---

  /**
   * @param  _systemCoin Address of the system coin
   * @param  _protocolToken Address of the protocol token
   * @param  _oracleRelayer Address of the OracleRelayer
   * @param  _emissionsController Address of the EmissionsController
   * @param  _coinJoin Address of the CoinJoin contract
   * @param  _collateralJoinFactory Address of the CollateralJoinFactory
   */
  constructor(
    address _systemCoin,
    address _protocolToken,
    address _oracleRelayer,
    address _emissionsController,
    address _coinJoin,
    address _collateralJoinFactory
  ) ERC4626(IERC20(_systemCoin)) ERC20('Staked HAI', 'sHAI') Authorizable(msg.sender) {
    systemCoin = ISystemCoin(_systemCoin);
    protocolToken = IProtocolToken(_protocolToken);
    oracleRelayer = IOracleRelayer(_oracleRelayer);
    emissionsController = IEmissionsController(_emissionsController);
    coinJoin = ICoinJoin(_coinJoin);
    collateralJoinFactory = ICollateralJoinFactory(_collateralJoinFactory);
    lastInternalCoinSweepTime = block.timestamp;
    kiteRewardsActive = true;
  }

  // --- Methods ---

  // --- Rewards ---

  /// @inheritdoc IStabilityPool
  function claimRewardsFromEmissionsController() external nonReentrant returns (uint256 _amount) {
    if (!kiteRewardsActive) revert StabilityPool_RewardsInactive();
    _amount = emissionsController.claimRewardsForStabilityPool();
    if (_amount > 0) {
      // KITE is transferred to this contract by EmissionsController
      // Update reward integral will detect it on next call
      emit ClaimRewardsFromEmissionsController(_amount);
    }
    _accrueKite();
  }

  /// @inheritdoc IStabilityPool
  function claimRewards() external nonReentrant returns (uint256 _amount) {
    _accrueKite();
    _checkpoint(msg.sender);
    _amount = _claim(msg.sender, msg.sender);
  }

  /// @inheritdoc IStabilityPool
  function pendingRewards(address _user) external view returns (uint256 _amount) {
    uint256 _currentIntegral = kiteRewardIntegral;
    if (kiteRewardsActive) {
      uint256 _totalSupply = totalSupply();
      if (_totalSupply > 0) {
        uint256 _currentKiteBalance = protocolToken.balanceOf(address(this));
        if (_currentKiteBalance > kiteRewardRemaining) {
          uint256 _newKite = _currentKiteBalance - kiteRewardRemaining;
          _currentIntegral += (_newKite * WAD) / _totalSupply;
        }
      }
    }

    uint256 _accrued = (balanceOf(_user) * _currentIntegral) / WAD;
    uint256 _pending = _accrued > rewardDebt[_user] ? _accrued - rewardDebt[_user] : 0;
    _amount = claimable[_user] + _pending;
  }

  /// @inheritdoc IStabilityPool
  function enableTransfers() external isAuthorized {
    if (transfersEnabled) revert StabilityPool_TransfersAlreadyEnabled();

    address _receiver = emissionsController.stabilityRewardsReceiver();
    if (_receiver == address(0) || _receiver == address(this)) revert StabilityPool_InvalidRewardsReceiver();

    _accrueKite();
    kiteRewardsActive = false;
    transfersEnabled = true;

    emit KiteRewardsDeactivated(kiteRewardIntegral, kiteRewardRemaining);
    emit TransfersEnabled();
  }

  /// @inheritdoc IStabilityPool
  function sweepInternalCoin() external nonReentrant returns (uint256 _exitedWad) {
    if (block.timestamp < lastInternalCoinSweepTime + HOUR) {
      revert StabilityPool_InternalCoinSweepTooFrequent();
    }
    lastInternalCoinSweepTime = block.timestamp;

    ISAFEEngine _safeEngine = coinJoin.safeEngine();
    uint256 _internalRad = _safeEngine.coinBalance(address(this));
    _exitedWad = _internalRad / RAY;
    if (_exitedWad > 0) {
      _safeEngine.approveSAFEModification(address(coinJoin));
      coinJoin.exit(address(this), _exitedWad);
    }

    emit SweepInternalCoin(_exitedWad);
  }

  // --- Strategy Configuration ---

  /// @inheritdoc IStabilityPool
  function strategySteps(bytes32 _collateralType, uint256 _idx) external view returns (StepConfig memory _stepConfig) {
    return _strategySteps[_collateralType][_idx];
  }

  /// @inheritdoc IStabilityPool
  function strategyStepsLength(bytes32 _collateralType) external view returns (uint256 _length) {
    return _strategySteps[_collateralType].length;
  }

  /// @inheritdoc IStabilityPool
  function setStrategySteps(bytes32 _collateralType, StepConfig[] calldata _steps) external isAuthorized {
    if (_steps.length == 0) revert StabilityPool_NoStrategySteps();

    delete _strategySteps[_collateralType];
    address[] memory _stepAddresses = new address[](_steps.length);

    for (uint256 _i = 0; _i < _steps.length; _i++) {
      StepConfig calldata _step = _steps[_i];
      if (_step.step == address(0) || !isWhitelistedStep[_step.step]) {
        revert StabilityPool_InvalidStrategyStep();
      }
      if (_step.slippageBps > _MAX_SLIPPAGE_BPS) revert StabilityPool_InvalidSlippageBps();
      _strategySteps[_collateralType].push(_step);
      _stepAddresses[_i] = _step.step;
    }

    emit SetStrategySteps(_collateralType, _stepAddresses);
  }

  /// @inheritdoc IStabilityPool
  function clearStrategySteps(bytes32 _collateralType) external isAuthorized {
    delete _strategySteps[_collateralType];
    emit ClearStrategySteps(_collateralType);
  }

  /// @inheritdoc IStabilityPool
  function setStepWhitelist(address _step, bool _allowed) external isAuthorized {
    if (_step == address(0)) revert StabilityPool_InvalidStrategyStep();
    isWhitelistedStep[_step] = _allowed;
    emit SetStepWhitelist(_step, _allowed);
  }

  /// @inheritdoc IStabilityPool
  function setCollateralSlippageBps(bytes32 _collateralType, uint16 _bps) external isAuthorized {
    if (_bps > _MAX_SLIPPAGE_BPS) revert StabilityPool_InvalidSlippageBps();
    collateralSlippageBps[_collateralType] = _bps;
    emit SetCollateralSlippageBps(_collateralType, _bps);
  }

  /// @inheritdoc IStabilityPool
  function setStepTypeSlippageBps(bytes32 _stepType, uint16 _bps) external isAuthorized {
    if (_bps > _MAX_SLIPPAGE_BPS) revert StabilityPool_InvalidSlippageBps();
    stepTypeSlippageBps[_stepType] = _bps;
    emit SetStepTypeSlippageBps(_stepType, _bps);
  }

  /// @inheritdoc IStabilityPool
  function previewSwapToHai(
    bytes32 _collateralType,
    uint256 _collateralAmount
  ) external view returns (uint256 _expectedHai) {
    (address _collateralJoinAddr, address _collateralToken,) = _resolveCollateral(_collateralType);
    if (_collateralJoinAddr == address(0)) revert StabilityPool_InvalidCollateralJoin();
    (_expectedHai,) = _previewStrategy(_collateralType, _collateralToken, _collateralAmount);
  }

  // --- Auction Covering ---

  /// @inheritdoc IStabilityPool
  function coverAndRepayDebt(
    address _auctionHouse,
    uint256 _auctionId,
    uint256 _bidAmount,
    bytes32 _collateralType
  ) external nonReentrant returns (int256 _profit) {
    if (_strategySteps[_collateralType].length == 0) revert StabilityPool_NoStrategySteps();

    ICollateralAuctionHouse _auction = ICollateralAuctionHouse(_auctionHouse);
    if (_auction.collateralType() != _collateralType) revert StabilityPool_CollateralTypeMismatch();

    address _collateralJoinAddr;
    uint256 _multiplier;
    bytes[] memory _minOutsByStep;
    {
      (uint256 _estimatedCollateralBought, uint256 _estimatedAdjustedBid) =
        _auction.getCollateralBought(_auctionId, _bidAmount);
      if (_estimatedCollateralBought == 0) {
        return int256(0);
      }

      address _collateralToken;
      (_collateralJoinAddr, _collateralToken, _multiplier) = _resolveCollateral(_collateralType);
      uint256 _estimatedCollateralWei = _toCollateralWei(_estimatedCollateralBought, _multiplier);

      (uint256 _expectedHai, bytes[] memory _previewMinOuts) =
        _previewStrategy(_collateralType, _collateralToken, _estimatedCollateralWei);
      if (_expectedHai < _estimatedAdjustedBid) revert StabilityPool_NotProfitable();
      _minOutsByStep = _previewMinOuts;
    }

    ISAFEEngine _safeEngine = coinJoin.safeEngine();
    uint256 _coinBalanceBefore = _safeEngine.coinBalance(address(this));
    _joinSystemCoinIfNeeded(_bidAmount, _coinBalanceBefore);
    _approveAuctionHouse(_safeEngine, _auctionHouse);

    (uint256 _actualCollateralBought, uint256 _actualAdjustedBid) = _auction.buyCollateral(_auctionId, _bidAmount);
    ICollateralJoin(_collateralJoinAddr).exit(address(this), _toCollateralWei(_actualCollateralBought, _multiplier));

    uint256 _haiReceived = _executeStrategy(_collateralType, _minOutsByStep);
    if (_haiReceived < _actualAdjustedBid) revert StabilityPool_NotProfitable();

    _exitExtraInternalCoin(_coinBalanceBefore);
    _profit = int256(_haiReceived) - int256(_actualAdjustedBid);
    emit CoverAndRepayDebt(_auctionId, _collateralType, _actualCollateralBought, _actualAdjustedBid, _haiReceived);
  }

  // --- Internal Methods ---

  function _accrueKite() internal {
    if (!kiteRewardsActive) return;

    uint256 _currentKiteBalance = protocolToken.balanceOf(address(this));
    if (_currentKiteBalance <= kiteRewardRemaining) return;

    uint256 _newKite = _currentKiteBalance - kiteRewardRemaining;
    uint256 _totalSupply = totalSupply();
    if (_totalSupply == 0) return;

    kiteRewardIntegral += (_newKite * WAD) / _totalSupply;
    kiteRewardRemaining = _currentKiteBalance;
  }

  function _checkpoint(address _user) internal {
    if (_user == address(0)) return;
    uint256 _accrued = (balanceOf(_user) * kiteRewardIntegral) / WAD;
    uint256 _debt = rewardDebt[_user];
    if (_accrued > _debt) {
      claimable[_user] += _accrued - _debt;
    }
  }

  function _syncRewardDebt(address _user) internal {
    if (_user == address(0)) return;
    rewardDebt[_user] = (balanceOf(_user) * kiteRewardIntegral) / WAD;
  }

  function _claim(address _user, address _receiver) internal returns (uint256 _amount) {
    _amount = claimable[_user];
    if (_amount == 0) return 0;

    claimable[_user] = 0;
    kiteRewardRemaining -= _amount;
    IERC20(address(protocolToken)).safeTransfer(_receiver, _amount);
    emit ClaimRewards(_user, _amount);
  }

  // --- Strategy Helpers ---

  function _resolveSlippageBps(
    bytes32 _collateralType,
    StepConfig storage _config,
    bytes32 _stepType
  ) internal view returns (uint16 _slippageBps) {
    if (_config.slippageBps > 0) return _config.slippageBps;

    uint16 _collateralBps = collateralSlippageBps[_collateralType];
    if (_collateralBps > 0) return _collateralBps;

    return stepTypeSlippageBps[_stepType];
  }

  function _previewStrategy(
    bytes32 _collateralType,
    address _collateralToken,
    uint256 _collateralAmount
  ) internal view returns (uint256 _expectedHai, bytes[] memory _minOutsByStep) {
    StepConfig[] storage _steps = _strategySteps[_collateralType];
    if (_steps.length == 0) revert StabilityPool_NoStrategySteps();

    VirtualBalance[] memory _balances = new VirtualBalance[](_steps.length * 8 + 1);
    uint256 _balancesLength = _addVirtualBalance(_balances, 0, _collateralToken, _collateralAmount);

    _minOutsByStep = new bytes[](_steps.length);
    for (uint256 _i = 0; _i < _steps.length; _i++) {
      StepConfig storage _config = _steps[_i];
      if (!isWhitelistedStep[_config.step]) revert StabilityPool_StepNotWhitelisted();

      address _inputToken = IStrategyStep(_config.step).inputToken(_config.data);
      uint256 _amountIn = _getVirtualBalance(_balances, _balancesLength, _inputToken);
      uint256[] memory _outputs = IStrategyStep(_config.step).preview(_config.data, _amountIn);
      address[] memory _outputTokens = IStrategyStep(_config.step).outputTokens(_config.data);
      if (_outputs.length != _outputTokens.length) revert StabilityPool_InvalidStrategyStep();

      uint16 _slippageBps = _resolveSlippageBps(_collateralType, _config, IStrategyStep(_config.step).stepType());
      uint256[] memory _minOuts = new uint256[](_outputs.length);

      _balancesLength = _setVirtualBalance(_balances, _balancesLength, _inputToken, 0);
      for (uint256 _j = 0; _j < _outputs.length; _j++) {
        uint256 _minOut = (_outputs[_j] * (_MAX_SLIPPAGE_BPS - _slippageBps)) / _MAX_SLIPPAGE_BPS;
        _minOuts[_j] = _minOut;
        _balancesLength = _addVirtualBalance(_balances, _balancesLength, _outputTokens[_j], _outputs[_j]);
      }

      _minOutsByStep[_i] = abi.encode(_minOuts);
    }

    _expectedHai = _getVirtualBalance(_balances, _balancesLength, address(systemCoin));
  }

  function _executeStrategy(
    bytes32 _collateralType,
    bytes[] memory _minOutsByStep
  ) internal returns (uint256 _haiReceived) {
    StepConfig[] storage _steps = _strategySteps[_collateralType];
    uint256 _haiBefore = systemCoin.balanceOf(address(this));

    for (uint256 _i = 0; _i < _steps.length; _i++) {
      StepConfig storage _config = _steps[_i];
      if (!isWhitelistedStep[_config.step]) revert StabilityPool_StepNotWhitelisted();

      address _inputToken = IStrategyStep(_config.step).inputToken(_config.data);
      uint256 _amountIn = IERC20(_inputToken).balanceOf(address(this));
      uint256[] memory _minOuts = abi.decode(_minOutsByStep[_i], (uint256[]));

      (bool _success, bytes memory _result) = _config.step.delegatecall(
        abi.encodeWithSelector(IStrategyStep.execute.selector, _config.data, _amountIn, _minOuts)
      );
      if (!_success) {
        if (_result.length > 0) {
          assembly {
            revert(add(_result, 32), mload(_result))
          }
        }
        revert StabilityPool_DelegatecallFailed();
      }

      uint256[] memory _outputs = abi.decode(_result, (uint256[]));
      if (_outputs.length != _minOuts.length) revert StabilityPool_InvalidStrategyStep();
      for (uint256 _j = 0; _j < _outputs.length; _j++) {
        if (_outputs[_j] < _minOuts[_j]) revert StabilityPool_NotProfitable();
      }
    }

    _haiReceived = systemCoin.balanceOf(address(this)) - _haiBefore;
  }

  function _resolveCollateral(bytes32 _collateralType)
    internal
    view
    returns (address _collateralJoinAddr, address _collateralToken, uint256 _multiplier)
  {
    _collateralJoinAddr = collateralJoinFactory.collateralJoins(_collateralType);
    if (_collateralJoinAddr == address(0)) revert StabilityPool_InvalidCollateralJoin();

    ICollateralJoin _collateralJoin = ICollateralJoin(_collateralJoinAddr);
    _collateralToken = address(_collateralJoin.collateral());
    _multiplier = _collateralJoin.multiplier();
  }

  function _toCollateralWei(uint256 _wad, uint256 _multiplier) internal pure returns (uint256 _wei) {
    if (_multiplier == 0) return _wad;
    return _wad / (10 ** _multiplier);
  }

  function _joinSystemCoinIfNeeded(uint256 _bidAmount, uint256 _coinBalanceBefore) internal {
    uint256 _requiredRad = _bidAmount * RAY;
    if (_coinBalanceBefore >= _requiredRad) return;

    uint256 _radMissing = _requiredRad - _coinBalanceBefore;
    uint256 _joinWad = (_radMissing + RAY - 1) / RAY;
    IERC20(address(systemCoin)).forceApprove(address(coinJoin), _joinWad);
    coinJoin.join(address(this), _joinWad);
  }

  function _approveAuctionHouse(ISAFEEngine _safeEngine, address _auctionHouse) internal {
    if (_safeApprovedAuctionHouse[_auctionHouse]) return;
    _safeApprovedAuctionHouse[_auctionHouse] = true;
    _safeEngine.approveSAFEModification(_auctionHouse);
  }

  function _exitExtraInternalCoin(uint256 _coinBalanceBefore) internal {
    uint256 _coinBalanceAfter = coinJoin.safeEngine().coinBalance(address(this));
    if (_coinBalanceAfter <= _coinBalanceBefore) return;

    uint256 _extraRad = _coinBalanceAfter - _coinBalanceBefore;
    uint256 _extraWad = _extraRad / RAY;
    if (_extraWad > 0) {
      coinJoin.exit(address(this), _extraWad);
    }
  }

  function _getVirtualBalance(
    VirtualBalance[] memory _balances,
    uint256 _length,
    address _token
  ) internal pure returns (uint256 _amount) {
    for (uint256 _i = 0; _i < _length; _i++) {
      if (_balances[_i].token == _token) return _balances[_i].amount;
    }
    return 0;
  }

  function _setVirtualBalance(
    VirtualBalance[] memory _balances,
    uint256 _length,
    address _token,
    uint256 _amount
  ) internal pure returns (uint256 _newLength) {
    for (uint256 _i = 0; _i < _length; _i++) {
      if (_balances[_i].token == _token) {
        _balances[_i].amount = _amount;
        return _length;
      }
    }

    _balances[_length] = VirtualBalance({token: _token, amount: _amount});
    return _length + 1;
  }

  function _addVirtualBalance(
    VirtualBalance[] memory _balances,
    uint256 _length,
    address _token,
    uint256 _amountToAdd
  ) internal pure returns (uint256 _newLength) {
    for (uint256 _i = 0; _i < _length; _i++) {
      if (_balances[_i].token == _token) {
        _balances[_i].amount += _amountToAdd;
        return _length;
      }
    }

    _balances[_length] = VirtualBalance({token: _token, amount: _amountToAdd});
    return _length + 1;
  }

  // --- Hooks ---

  function _update(address _from, address _to, uint256 _value) internal virtual override {
    if (!transfersEnabled && _from != address(0) && _to != address(0)) {
      revert StabilityPool_TransfersDisabled();
    }

    _accrueKite();
    if (_from != address(0)) {
      _checkpoint(_from);
    }
    if (_to != address(0) && _to != _from) {
      _checkpoint(_to);
    }

    super._update(_from, _to, _value);

    if (_from != address(0)) {
      _syncRewardDebt(_from);
    }
    if (_to != address(0) && _to != _from) {
      _syncRewardDebt(_to);
    }
  }

  function _deposit(address _caller, address _receiver, uint256 _assets, uint256 _shares) internal virtual override {
    if (kiteRewardsActive) {
      uint256 _claimed = emissionsController.claimRewardsForStabilityPool();
      if (_claimed > 0) {
        emit ClaimRewardsFromEmissionsController(_claimed);
      }
      _accrueKite();
    }

    super._deposit(_caller, _receiver, _assets, _shares);
  }

  function _withdraw(
    address _caller,
    address _receiver,
    address _owner,
    uint256 _assets,
    uint256 _shares
  ) internal virtual override {
    super._withdraw(_caller, _receiver, _owner, _assets, _shares);
    _claim(_owner, _owner);
  }

  function deposit(
    uint256 _assets,
    address _receiver
  ) public virtual override(ERC4626, IERC4626) nonReentrant returns (uint256 _shares) {
    return super.deposit(_assets, _receiver);
  }

  function mint(
    uint256 _shares,
    address _receiver
  ) public virtual override(ERC4626, IERC4626) nonReentrant returns (uint256 _assets) {
    return super.mint(_shares, _receiver);
  }

  function withdraw(
    uint256 _assets,
    address _receiver,
    address _owner
  ) public virtual override(ERC4626, IERC4626) nonReentrant returns (uint256 _shares) {
    return super.withdraw(_assets, _receiver, _owner);
  }

  function redeem(
    uint256 _shares,
    address _receiver,
    address _owner
  ) public virtual override(ERC4626, IERC4626) nonReentrant returns (uint256 _assets) {
    return super.redeem(_shares, _receiver, _owner);
  }
}
