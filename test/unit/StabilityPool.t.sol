// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {HaiTest} from '@test/utils/HaiTest.t.sol';
import {ERC20ForTest} from '@test/mocks/ERC20ForTest.sol';
import {StabilityPool} from '@contracts/StabilityPool.sol';
import {IStabilityPool} from '@interfaces/IStabilityPool.sol';
import {IStrategyStep} from '@interfaces/IStrategyStep.sol';
import {IEmissionsController} from '@interfaces/IEmissionsController.sol';
import {IAuthorizable} from '@interfaces/utils/IAuthorizable.sol';

contract MockEmissionsController {
  ERC20ForTest public kite;
  address public stabilityRewardsReceiver;
  uint256 public amountToClaim;

  constructor(ERC20ForTest _kite, address _stabilityRewardsReceiver) {
    kite = _kite;
    stabilityRewardsReceiver = _stabilityRewardsReceiver;
  }

  function claimRewardsForStabilityPool() external returns (uint256 _amount) {
    _amount = amountToClaim;
    amountToClaim = 0;
    if (_amount > 0) {
      kite.transfer(msg.sender, _amount);
    }
  }

  function setStabilityRewardsReceiver(address _receiver) external {
    stabilityRewardsReceiver = _receiver;
  }

  function setAmountToClaim(uint256 _amount) external {
    amountToClaim = _amount;
  }
}

contract MockStrategyStep is IStrategyStep {
  bytes32 internal constant _STEP_TYPE = bytes32('MOCK');

  function stepType() external pure returns (bytes32 _stepType) {
    return _STEP_TYPE;
  }

  function inputToken(bytes calldata _data) external pure returns (address _inputToken) {
    (_inputToken,) = abi.decode(_data, (address, address));
  }

  function outputTokens(bytes calldata _data) external pure returns (address[] memory _outputTokens) {
    (, address _output) = abi.decode(_data, (address, address));
    _outputTokens = new address[](1);
    _outputTokens[0] = _output;
  }

  function preview(bytes calldata, uint256 _amountIn) external pure returns (uint256[] memory _amountsOut) {
    _amountsOut = new uint256[](1);
    _amountsOut[0] = _amountIn;
  }

  function execute(
    bytes calldata,
    uint256 _amountIn,
    uint256[] calldata
  ) external pure returns (uint256[] memory _amountsOut) {
    _amountsOut = new uint256[](1);
    _amountsOut[0] = _amountIn;
  }
}

abstract contract Base is HaiTest {
  address deployer = label('deployer');
  address user = label('user');
  address user2 = label('user2');
  address postCutoverRewards = label('postCutoverRewards');

  ERC20ForTest systemCoin;
  ERC20ForTest protocolToken;
  MockEmissionsController emissionsController;
  StabilityPool stabilityPool;
  MockStrategyStep strategyStep;

  function setUp() public virtual {
    vm.startPrank(deployer);

    systemCoin = new ERC20ForTest();
    protocolToken = new ERC20ForTest();
    emissionsController = new MockEmissionsController(protocolToken, address(0));
    strategyStep = new MockStrategyStep();

    stabilityPool = new StabilityPool(
      address(systemCoin),
      address(protocolToken),
      mockContract('OracleRelayer'),
      address(emissionsController),
      mockContract('CoinJoin'),
      mockContract('CollateralJoinFactory')
    );

    emissionsController.setStabilityRewardsReceiver(address(stabilityPool));

    systemCoin.mint(user, 1000e18);
    systemCoin.mint(user2, 1000e18);

    vm.stopPrank();

    vm.prank(user);
    systemCoin.approve(address(stabilityPool), type(uint256).max);
    vm.prank(user2);
    systemCoin.approve(address(stabilityPool), type(uint256).max);
  }
}

contract Unit_StabilityPool_Constructor is Base {
  function test_Set_SystemCoin() public {
    assertEq(address(stabilityPool.systemCoin()), address(systemCoin));
  }
}

contract Unit_StabilityPool_TransferToggle is Base {
  function test_Revert_Transfer_When_Disabled() public {
    vm.prank(user);
    stabilityPool.deposit(100e18, user);

    vm.prank(user);
    vm.expectRevert(IStabilityPool.StabilityPool_TransfersDisabled.selector);
    stabilityPool.transfer(user2, 1e18);
  }

  function test_Revert_EnableTransfers_InvalidReceiver() public {
    vm.prank(deployer);
    vm.expectRevert(IStabilityPool.StabilityPool_InvalidRewardsReceiver.selector);
    stabilityPool.enableTransfers();
  }

  function test_EnableTransfers_OneWay() public {
    vm.prank(deployer);
    emissionsController.setStabilityRewardsReceiver(postCutoverRewards);

    vm.prank(deployer);
    stabilityPool.enableTransfers();

    assertEq(stabilityPool.transfersEnabled(), true);
    assertEq(stabilityPool.kiteRewardsActive(), false);

    vm.prank(deployer);
    vm.expectRevert(IStabilityPool.StabilityPool_TransfersAlreadyEnabled.selector);
    stabilityPool.enableTransfers();
  }

  function test_Transfer_After_Enable() public {
    vm.prank(user);
    stabilityPool.deposit(100e18, user);

    vm.prank(deployer);
    emissionsController.setStabilityRewardsReceiver(postCutoverRewards);
    vm.prank(deployer);
    stabilityPool.enableTransfers();

    vm.prank(user);
    stabilityPool.transfer(user2, 10e18);
    assertEq(stabilityPool.balanceOf(user2), 10e18);
  }
}

contract Unit_StabilityPool_Rewards is Base {
  function test_ClaimRewards_Without_Withdraw() public {
    vm.prank(user);
    stabilityPool.deposit(100e18, user);
    protocolToken.mint(address(stabilityPool), 10e18);

    vm.prank(user);
    uint256 _claimed = stabilityPool.claimRewards();
    assertEq(_claimed, 10e18);
    assertEq(protocolToken.balanceOf(user), 10e18);
  }

  function test_Deposit_Does_Not_Grant_PastRewards_To_NewShares() public {
    vm.prank(user);
    stabilityPool.deposit(100e18, user);
    protocolToken.mint(address(stabilityPool), 10e18);

    vm.prank(user);
    stabilityPool.deposit(100e18, user);

    vm.prank(user);
    uint256 _claimed = stabilityPool.claimRewards();
    assertEq(_claimed, 10e18);
  }

  function test_PartialWithdraw_DoesNotLose_RemainingRewards() public {
    vm.prank(user);
    stabilityPool.deposit(100e18, user);
    protocolToken.mint(address(stabilityPool), 10e18);

    vm.prank(user);
    stabilityPool.redeem(50e18, user, user);
    assertEq(protocolToken.balanceOf(user), 10e18);

    protocolToken.mint(address(stabilityPool), 10e18);
    vm.prank(user);
    stabilityPool.claimRewards();
    assertEq(protocolToken.balanceOf(user), 20e18);
  }

  function test_ClaimHistoricalRewards_AfterTransferCutover() public {
    vm.prank(user);
    stabilityPool.deposit(100e18, user);
    protocolToken.mint(address(stabilityPool), 10e18);

    vm.prank(deployer);
    emissionsController.setStabilityRewardsReceiver(postCutoverRewards);
    vm.prank(deployer);
    stabilityPool.enableTransfers();

    vm.prank(user);
    stabilityPool.transfer(user2, 100e18);

    vm.prank(user);
    uint256 _claimed = stabilityPool.claimRewards();
    assertEq(_claimed, 10e18);

    vm.prank(user2);
    uint256 _claimedUser2 = stabilityPool.claimRewards();
    assertEq(_claimedUser2, 0);
  }

  function test_Revert_ClaimFromEmissions_AfterCutover() public {
    vm.prank(deployer);
    emissionsController.setStabilityRewardsReceiver(postCutoverRewards);
    vm.prank(deployer);
    stabilityPool.enableTransfers();

    vm.prank(user);
    vm.expectRevert(IStabilityPool.StabilityPool_RewardsInactive.selector);
    stabilityPool.claimRewardsFromEmissionsController();
  }
}

contract Unit_StabilityPool_StrategyConfig is Base {
  function test_Revert_SetStrategySteps_UnwhitelistedStep() public {
    IStabilityPool.StepConfig[] memory _steps = new IStabilityPool.StepConfig[](1);
    _steps[0] = IStabilityPool.StepConfig({
      step: address(strategyStep),
      data: abi.encode(address(systemCoin), address(systemCoin)),
      slippageBps: 0
    });

    vm.prank(deployer);
    vm.expectRevert(IStabilityPool.StabilityPool_InvalidStrategyStep.selector);
    stabilityPool.setStrategySteps(bytes32('WSTETH'), _steps);
  }

  function test_SetStrategySteps_WhenWhitelisted() public {
    vm.prank(deployer);
    stabilityPool.setStepWhitelist(address(strategyStep), true);

    IStabilityPool.StepConfig[] memory _steps = new IStabilityPool.StepConfig[](1);
    _steps[0] = IStabilityPool.StepConfig({
      step: address(strategyStep),
      data: abi.encode(address(systemCoin), address(systemCoin)),
      slippageBps: 0
    });

    vm.prank(deployer);
    stabilityPool.setStrategySteps(bytes32('WSTETH'), _steps);

    assertEq(stabilityPool.strategyStepsLength(bytes32('WSTETH')), 1);
  }

  function test_Revert_SetStrategySteps_Unauthorized() public {
    IStabilityPool.StepConfig[] memory _steps = new IStabilityPool.StepConfig[](1);
    _steps[0] = IStabilityPool.StepConfig({step: address(strategyStep), data: '', slippageBps: 0});

    vm.prank(user);
    vm.expectRevert(IAuthorizable.Unauthorized.selector);
    stabilityPool.setStrategySteps(bytes32('WSTETH'), _steps);
  }
}
