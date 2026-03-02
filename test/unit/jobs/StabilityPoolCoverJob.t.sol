// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {StabilityPoolCoverJobForTest, IStabilityPoolCoverJob} from '@test/mocks/StabilityPoolCoverJobForTest.sol';
import {IStabilityPool} from '@interfaces/IStabilityPool.sol';
import {IStabilityFeeTreasury} from '@interfaces/IStabilityFeeTreasury.sol';
import {IJob} from '@interfaces/jobs/IJob.sol';
import {IModifiable} from '@interfaces/utils/IModifiable.sol';
import {HaiTest, stdStorage, StdStorage} from '@test/utils/HaiTest.t.sol';

import {Assertions} from '@libraries/Assertions.sol';

abstract contract Base is HaiTest {
  using stdStorage for StdStorage;

  address deployer = label('deployer');
  address authorizedAccount = label('authorizedAccount');
  address user = label('user');

  IStabilityPool mockStabilityPool = IStabilityPool(mockContract('StabilityPool'));
  IStabilityFeeTreasury mockStabilityFeeTreasury = IStabilityFeeTreasury(mockContract('StabilityFeeTreasury'));

  StabilityPoolCoverJobForTest stabilityPoolCoverJob;

  uint256 constant REWARD_AMOUNT = 1e18;

  function setUp() public virtual {
    vm.startPrank(deployer);

    stabilityPoolCoverJob =
      new StabilityPoolCoverJobForTest(address(mockStabilityPool), address(mockStabilityFeeTreasury), REWARD_AMOUNT);
    label(address(stabilityPoolCoverJob), 'StabilityPoolCoverJob');

    stabilityPoolCoverJob.addAuthorization(authorizedAccount);

    vm.stopPrank();
  }

  function _mockCoverAndRepayDebt(
    address _auctionHouse,
    uint256 _auctionId,
    uint256 _bidAmount,
    bytes32 _collateralType,
    int256 _profit
  ) internal {
    vm.mockCall(
      address(mockStabilityPool),
      abi.encodeCall(mockStabilityPool.coverAndRepayDebt, (_auctionHouse, _auctionId, _bidAmount, _collateralType)),
      abi.encode(_profit)
    );
  }

  function _mockRewardAmount(uint256 _rewardAmount) internal {
    stdstore.target(address(stabilityPoolCoverJob)).sig(IJob.rewardAmount.selector).checked_write(_rewardAmount);
  }

  function _mockShouldWork(bool _shouldWork) internal {
    // BUG: Accessing packed slots is not supported by Std Storage
    stabilityPoolCoverJob.setShouldWork(_shouldWork);
  }
}

contract Unit_StabilityPoolCoverJob_Constructor is Base {
  event AddAuthorization(address _account);

  modifier happyPath() {
    vm.startPrank(user);
    _;
  }

  function test_Emit_AddAuthorization() public happyPath {
    vm.expectEmit();
    emit AddAuthorization(user);

    new StabilityPoolCoverJobForTest(address(mockStabilityPool), address(mockStabilityFeeTreasury), REWARD_AMOUNT);
  }

  function test_Set_StabilityFeeTreasury() public happyPath {
    assertEq(address(stabilityPoolCoverJob.stabilityFeeTreasury()), address(mockStabilityFeeTreasury));
  }

  function test_Set_RewardAmount() public happyPath {
    assertEq(stabilityPoolCoverJob.rewardAmount(), REWARD_AMOUNT);
  }

  function test_Set_StabilityPool(address _stabilityPool) public happyPath mockAsContract(_stabilityPool) {
    stabilityPoolCoverJob =
      new StabilityPoolCoverJobForTest(_stabilityPool, address(mockStabilityFeeTreasury), REWARD_AMOUNT);

    assertEq(address(stabilityPoolCoverJob.stabilityPool()), _stabilityPool);
  }

  function test_Set_ShouldWork() public happyPath {
    assertEq(stabilityPoolCoverJob.shouldWork(), true);
  }

  function test_Revert_Null_StabilityPool() public {
    vm.expectRevert(abi.encodeWithSelector(Assertions.NoCode.selector, address(0)));

    new StabilityPoolCoverJobForTest(address(0), address(mockStabilityFeeTreasury), REWARD_AMOUNT);
  }

  function test_Revert_Null_StabilityFeeTreasury() public {
    vm.expectRevert(abi.encodeWithSelector(Assertions.NoCode.selector, address(0)));

    new StabilityPoolCoverJobForTest(address(mockStabilityPool), address(0), REWARD_AMOUNT);
  }

  function test_Revert_Null_RewardAmount() public {
    vm.expectRevert(Assertions.NullAmount.selector);

    new StabilityPoolCoverJobForTest(address(mockStabilityPool), address(mockStabilityFeeTreasury), 0);
  }
}

contract Unit_StabilityPoolCoverJob_WorkCoverAndRepayDebt is Base {
  event Rewarded(address _rewardedAccount, uint256 _rewardAmount);

  function _mockValues(
    bool _shouldWork,
    address _auctionHouse,
    uint256 _auctionId,
    uint256 _bidAmount,
    bytes32 _collateralType,
    int256 _profit
  ) internal {
    _mockShouldWork(_shouldWork);
    _mockCoverAndRepayDebt(_auctionHouse, _auctionId, _bidAmount, _collateralType, _profit);
  }

  function test_Revert_NotWorkable(
    address _auctionHouse,
    uint256 _auctionId,
    uint256 _bidAmount,
    bytes32 _collateralType
  ) public {
    _mockValues(false, _auctionHouse, _auctionId, _bidAmount, _collateralType, 1);

    vm.expectRevert(IJob.NotWorkable.selector);

    stabilityPoolCoverJob.workCoverAndRepayDebt(_auctionHouse, _auctionId, _bidAmount, _collateralType);
  }

  function test_Revert_NonPositiveProfit(
    address _auctionHouse,
    uint256 _auctionId,
    uint256 _bidAmount,
    bytes32 _collateralType
  ) public {
    _mockValues(true, _auctionHouse, _auctionId, _bidAmount, _collateralType, 0);

    vm.expectRevert(IStabilityPoolCoverJob.StabilityPoolCoverJob_NonPositiveProfit.selector);

    stabilityPoolCoverJob.workCoverAndRepayDebt(_auctionHouse, _auctionId, _bidAmount, _collateralType);
  }

  function test_Call_StabilityPool_CoverAndRepayDebt(
    address _auctionHouse,
    uint256 _auctionId,
    uint256 _bidAmount,
    bytes32 _collateralType
  ) public {
    _mockValues(true, _auctionHouse, _auctionId, _bidAmount, _collateralType, 1);
    vm.expectCall(
      address(mockStabilityPool),
      abi.encodeCall(mockStabilityPool.coverAndRepayDebt, (_auctionHouse, _auctionId, _bidAmount, _collateralType)),
      1
    );

    stabilityPoolCoverJob.workCoverAndRepayDebt(_auctionHouse, _auctionId, _bidAmount, _collateralType);
  }

  function test_Return_Profit(
    address _auctionHouse,
    uint256 _auctionId,
    uint256 _bidAmount,
    bytes32 _collateralType,
    int256 _profit
  ) public {
    vm.assume(_profit > 0);
    _mockValues(true, _auctionHouse, _auctionId, _bidAmount, _collateralType, _profit);

    assertEq(
      stabilityPoolCoverJob.workCoverAndRepayDebt(_auctionHouse, _auctionId, _bidAmount, _collateralType), _profit
    );
  }

  function test_Emit_Rewarded(
    address _auctionHouse,
    uint256 _auctionId,
    uint256 _bidAmount,
    bytes32 _collateralType
  ) public {
    _mockValues(true, _auctionHouse, _auctionId, _bidAmount, _collateralType, 1);

    vm.expectEmit();
    emit Rewarded(user, REWARD_AMOUNT);

    vm.prank(user);
    stabilityPoolCoverJob.workCoverAndRepayDebt(_auctionHouse, _auctionId, _bidAmount, _collateralType);
  }
}

contract Unit_StabilityPoolCoverJob_ModifyParameters is Base {
  modifier happyPath() {
    vm.startPrank(authorizedAccount);
    _;
  }

  function test_Set_StabilityPool(address _stabilityPool) public happyPath mockAsContract(_stabilityPool) {
    stabilityPoolCoverJob.modifyParameters('stabilityPool', abi.encode(_stabilityPool));

    assertEq(address(stabilityPoolCoverJob.stabilityPool()), _stabilityPool);
  }

  function test_Set_StabilityFeeTreasury(address _stabilityFeeTreasury)
    public
    happyPath
    mockAsContract(_stabilityFeeTreasury)
  {
    stabilityPoolCoverJob.modifyParameters('stabilityFeeTreasury', abi.encode(_stabilityFeeTreasury));

    assertEq(address(stabilityPoolCoverJob.stabilityFeeTreasury()), _stabilityFeeTreasury);
  }

  function test_Set_ShouldWork(bool _shouldWork) public happyPath {
    stabilityPoolCoverJob.modifyParameters('shouldWork', abi.encode(_shouldWork));

    assertEq(stabilityPoolCoverJob.shouldWork(), _shouldWork);
  }

  function test_Set_RewardAmount(uint256 _rewardAmount) public happyPath {
    vm.assume(_rewardAmount != 0);

    stabilityPoolCoverJob.modifyParameters('rewardAmount', abi.encode(_rewardAmount));

    assertEq(stabilityPoolCoverJob.rewardAmount(), _rewardAmount);
  }

  function test_Revert_Null_StabilityPool() public {
    vm.startPrank(authorizedAccount);

    vm.expectRevert(abi.encodeWithSelector(Assertions.NoCode.selector, address(0)));

    stabilityPoolCoverJob.modifyParameters('stabilityPool', abi.encode(address(0)));
  }

  function test_Revert_Null_StabilityFeeTreasury() public {
    vm.startPrank(authorizedAccount);

    vm.expectRevert(abi.encodeWithSelector(Assertions.NoCode.selector, address(0)));

    stabilityPoolCoverJob.modifyParameters('stabilityFeeTreasury', abi.encode(address(0)));
  }

  function test_Revert_Null_RewardAmount() public {
    vm.startPrank(authorizedAccount);

    vm.expectRevert(Assertions.NullAmount.selector);

    stabilityPoolCoverJob.modifyParameters('rewardAmount', abi.encode(0));
  }

  function test_Revert_UnrecognizedParam(bytes memory _data) public {
    vm.startPrank(authorizedAccount);

    vm.expectRevert(IModifiable.UnrecognizedParam.selector);

    stabilityPoolCoverJob.modifyParameters('unrecognizedParam', _data);
  }
}
