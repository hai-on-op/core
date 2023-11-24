// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {IPIDController, PIDController} from '@contracts/PIDController.sol';
import {HaiTest, stdStorage, StdStorage} from '@test/utils/HaiTest.t.sol';
import {InternalCallsWatcher, InternalCallsExtension} from '@test/utils/InternalCallsWatcher.sol';
import {PIDControllerForTest, MockPIDController} from '@test/mocks/PIDControllerForTest.sol';

import '@script/Params.s.sol';

import {Math, RAY, WAD} from '@libraries/Math.sol';
import {Assertions} from '@libraries/Assertions.sol';

contract Base is HaiTest {
  IPIDController pidController;
  IPIDController.PIDControllerParams params;
  IPIDController.ControllerGains gains;
  address watcher;
  address deployer = label('deployer');

  using stdStorage for StdStorage;

  uint256 internal constant NEGATIVE_RATE_LIMIT = RAY - 1;
  uint256 internal constant POSITIVE_RATE_LIMIT = uint256(type(int256).max);
  int256 constant PID_INTEGRAL_GAIN = 1e18;
  int256 constant PID_PROPORTIONAL_GAIN = 1e18;
  uint256 constant PID_PER_SECOND_CUMULATIVE_LEAK = 999_997_208_243_937_652_252_849_536; // 1% per hour
  uint256 constant PID_NOISE_BARRIER = 1e18;
  uint256 constant PID_FEEDBACK_OUTPUT_UPPER_BOUND = 1e45; // unbounded
  int256 constant PID_FEEDBACK_OUTPUT_LOWER_BOUND = -int256(1e27 - 1); // unbounded
  uint256 constant PID_PERIOD_SIZE = 1 hours;
  uint256 constant PID_UPDATE_RATE = 1 days;

  MockPIDController mockPIDController = new MockPIDController();

  function _createPidController(IPIDController.DeviationObservation memory _importedState) internal {
    vm.prank(deployer);

    IPIDController.ControllerGains memory _pidControllerGains =
      IPIDController.ControllerGains({kp: gains.kp, ki: gains.ki});

    IPIDController.PIDControllerParams memory _pidControllerParams = IPIDController.PIDControllerParams({
      integralPeriodSize: params.integralPeriodSize,
      perSecondCumulativeLeak: params.perSecondCumulativeLeak,
      noiseBarrier: params.noiseBarrier,
      feedbackOutputUpperBound: params.feedbackOutputUpperBound,
      feedbackOutputLowerBound: params.feedbackOutputLowerBound
    });

    pidController = new PIDControllerForTest({
      _cGains: _pidControllerGains,
      _pidParams: _pidControllerParams,
      _importedState: _importedState,
      _mockPIDController: mockPIDController
  });
  }

  function setUp() public virtual {
    params = IPIDController.PIDControllerParams({
      noiseBarrier: PID_NOISE_BARRIER,
      perSecondCumulativeLeak: PID_PER_SECOND_CUMULATIVE_LEAK,
      feedbackOutputLowerBound: -int256(NEGATIVE_RATE_LIMIT),
      feedbackOutputUpperBound: POSITIVE_RATE_LIMIT / 2,
      integralPeriodSize: PID_PERIOD_SIZE
    });

    gains = IPIDController.ControllerGains({kp: 1e9, ki: 1e9});

    _createPidController(IPIDController.DeviationObservation(0, 0, 0));
    watcher = address(PIDControllerForTest(address(pidController)).watcher());

    PIDControllerForTest(address(pidController)).setCallSupper_getNextDeviationCumulative(false);
    PIDControllerForTest(address(pidController)).setCallSupper_getGainAdjustedPIOutput(false);
    PIDControllerForTest(address(pidController)).setCallSupper_getBoundedRedemptionRate(false);
    PIDControllerForTest(address(pidController)).setCallSupper_updateDeviation(false);
  }

  // --- Params ---

  function _mockIntegralPeriodSize(uint256 _integralPeriodSize) internal {
    stdstore.target(address(pidController)).sig(IPIDController.params.selector).depth(0).checked_write(
      _integralPeriodSize
    );
  }

  function _mockPerSecondCumulativeLeak(uint256 _perSecondCumulativeLeak) internal {
    stdstore.target(address(pidController)).sig(IPIDController.params.selector).depth(1).checked_write(
      _perSecondCumulativeLeak
    );
  }

  function _mockNoiseBarrier(uint256 _noiseBarrier) internal {
    stdstore.target(address(pidController)).sig(IPIDController.params.selector).depth(2).checked_write(_noiseBarrier);
  }

  function _mockFeedbackOutputUpperBound(uint256 _feedbackOutputUpperBound) internal {
    stdstore.target(address(pidController)).sig(IPIDController.params.selector).depth(3).checked_write(
      _feedbackOutputUpperBound
    );
  }

  function _mockFeedbackOutputLowerBound(int256 _feedbackOutputLowerBound) internal {
    // casts to uint256 because stdstore does not support int256
    stdstore.target(address(pidController)).sig(IPIDController.params.selector).depth(4).checked_write(
      uint256(_feedbackOutputLowerBound)
    );
  }

  // --- Deviation Terms ---

  function _mockGetProportionalTerm(int256 _proportionalTerm) internal {
    vm.mockCall(
      address(mockPIDController),
      abi.encodeWithSelector(MockPIDController.mock_getProportionalTerm.selector),
      abi.encode(_proportionalTerm)
    );
  }

  function _mockLastUpdateTime(uint256 _updateTime) internal {
    stdstore.target(address(pidController)).sig(IPIDController.deviationObservation.selector).depth(0).checked_write(
      _updateTime
    );
  }

  function _mockProportionalTerm(int256 _proportionalTerm) internal {
    // casts to uint256 because stdstore does not support int256
    stdstore.target(address(pidController)).sig(IPIDController.deviationObservation.selector).depth(1).checked_write(
      uint256(_proportionalTerm)
    );
  }

  function _mockIntegralTerm(int256 _proportionalTerm) internal {
    // casts to uint256 because stdstore does not support int256
    stdstore.target(address(pidController)).sig(IPIDController.deviationObservation.selector).depth(2).checked_write(
      uint256(_proportionalTerm)
    );
  }

  function _mockControllerGains(IPIDController.ControllerGains memory _gains) internal {
    stdstore.target(address(pidController)).sig(IPIDController.controllerGains.selector).depth(0).checked_write(
      // casts to uint256 because stdstore does not support int256
      uint256(_gains.kp)
    );
    stdstore.target(address(pidController)).sig(IPIDController.controllerGains.selector).depth(1).checked_write(
      uint256(_gains.ki)
    );
  }

  function _mockGetNextDeviationCumulative(int256 _cumulativeDeviation, int256 _appliedDeviation) internal {
    vm.mockCall(
      address(mockPIDController),
      abi.encodeWithSelector(MockPIDController.mock_getNextDeviationCumulative.selector),
      abi.encode(_cumulativeDeviation, _appliedDeviation)
    );
  }

  function _mockGetGainAdjustedPIOutput(int256 _piOutput) internal {
    vm.mockCall(
      address(mockPIDController),
      abi.encodeWithSelector(MockPIDController.mock_getGainAdjustedPIOutput.selector),
      abi.encode(_piOutput)
    );
  }

  function _mockBreakNoiseBarrier(bool _breaksNoiseBarrier) internal {
    vm.mockCall(
      address(mockPIDController),
      abi.encodeWithSelector(MockPIDController.mock_breaksNoiseBarrier.selector),
      abi.encode(_breaksNoiseBarrier)
    );
  }

  function _mockGetBoundedRedemptionRate(uint256 _newRedemptionRate) internal {
    vm.mockCall(
      address(mockPIDController),
      abi.encodeWithSelector(MockPIDController.mock_getBoundedRedemptionRate.selector),
      abi.encode(_newRedemptionRate)
    );
  }

  function setCallSuper(bool _callSuper) public {
    PIDControllerForTest(address(pidController)).setCallSuper(_callSuper);
  }

  function _mockBoundedPIOutput(int256 _boundedPiOutput) internal {
    vm.mockCall(
      address(mockPIDController),
      abi.encodeWithSelector(MockPIDController.mock_getBoundedPIOutput.selector),
      abi.encode(_boundedPiOutput)
    );
  }

  function _mockGetGainAdjustedTerms(int256 _adjustedProportionalTerm, int256 _adjustedIntegralTerm) internal {
    vm.mockCall(
      address(mockPIDController),
      abi.encodeWithSelector(MockPIDController.mock_getGainAdjustedTerms.selector),
      abi.encode(_adjustedProportionalTerm, _adjustedIntegralTerm)
    );
  }

  function _mockGetNextRedemptionRate(
    uint256 _newRedemptionRate,
    int256 _proportionalTerm,
    int256 _cumulativeDeviation
  ) internal {
    vm.mockCall(
      address(mockPIDController),
      abi.encodeWithSelector(MockPIDController.mock_getNextRedemptionRate.selector),
      abi.encode(_newRedemptionRate, _proportionalTerm, _cumulativeDeviation)
    );
  }

  modifier authorized() {
    vm.startPrank(deployer);
    _;
  }
}

contract Unit_PIDController_Constructor is Base {
  function test_Set_ProportionalGain() public {
    assertEq(pidController.controllerGains().kp, gains.kp);
  }

  function test_Set_IntegralGain() public {
    assertEq(pidController.controllerGains().ki, gains.ki);
  }

  function test_Set_PerSecondCumulativeLeak() public {
    assertEq(pidController.params().perSecondCumulativeLeak, params.perSecondCumulativeLeak);
  }

  function test_Set_IntegralPeriodSize() public {
    assertEq(pidController.params().integralPeriodSize, params.integralPeriodSize);
  }

  function test_Set_NoiseBarrier() public {
    assertEq(pidController.params().noiseBarrier, params.noiseBarrier);
  }

  function test_Set_FeedbackOutputUpperBound() public {
    assertEq(pidController.params().feedbackOutputUpperBound, params.feedbackOutputUpperBound);
  }

  function test_Set_FeedbackOutputLowerBound() public {
    assertEq(pidController.params().feedbackOutputLowerBound, params.feedbackOutputLowerBound);
  }

  function test_Set_LastUpdateTime(uint256 _lastUpdateTime, uint256 _timestamp) public {
    vm.assume(_lastUpdateTime <= _timestamp);
    vm.warp(_timestamp);
    int256[] memory _importedState = new int256[](5);
    _importedState[0] = int256(_lastUpdateTime);
    _createPidController(
      IPIDController.DeviationObservation({timestamp: _lastUpdateTime, proportional: 0, integral: 0})
    );

    assertEq(pidController.deviationObservation().timestamp, _lastUpdateTime);
  }

  function test_Set_Deviation_Observation(
    uint256 _blockTimestamp,
    uint256 _timestamp,
    int256 _proportional,
    int256 _integral
  ) public {
    vm.assume(_timestamp < _blockTimestamp);
    vm.assume(_timestamp > 0 && _timestamp < 2 ** 255);
    vm.warp(_blockTimestamp);

    _createPidController(
      IPIDController.DeviationObservation({timestamp: _timestamp, proportional: _proportional, integral: _integral})
    );

    (IPIDController.DeviationObservation memory _deviation) = pidController.deviationObservation();

    assertEq(_deviation.timestamp, _timestamp);
    assertEq(_deviation.proportional, _proportional);
    assertEq(_deviation.integral, _integral);
  }

  function test_NotSet_Deviation_Observation(int256 _proportional, int256 _integral) public {
    _createPidController(
      IPIDController.DeviationObservation({timestamp: 0, proportional: _proportional, integral: _integral})
    );

    (IPIDController.DeviationObservation memory _deviation) = pidController.deviationObservation();

    assertEq(_deviation.timestamp, 0);
    assertEq(_deviation.proportional, 0);
    assertEq(_deviation.integral, 0);
  }

  function test_Set_PIDControllerParams(IPIDController.PIDControllerParams memory _controllerParams) public {
    vm.assume(_controllerParams.integralPeriodSize != 0);
    vm.assume(_controllerParams.noiseBarrier != 0 && _controllerParams.noiseBarrier <= WAD);
    vm.assume(
      _controllerParams.feedbackOutputUpperBound != 0
        && _controllerParams.feedbackOutputUpperBound <= POSITIVE_RATE_LIMIT
    );
    vm.assume(
      _controllerParams.feedbackOutputLowerBound < 0
        && _controllerParams.feedbackOutputLowerBound >= -int256(NEGATIVE_RATE_LIMIT)
    );
    vm.assume(_controllerParams.perSecondCumulativeLeak <= RAY);

    pidController = new PIDController({
      _cGains: IPIDController.ControllerGains({kp: 1e9, ki: 1e9}),
      _pidParams: _controllerParams,
      _importedState: IPIDController.DeviationObservation(0, 0, 0)
  });
    assertEq(abi.encode(pidController.params()), abi.encode(_controllerParams));
  }

  function test_Revert_FeedbackOutputUpperBoundIsZero() public {
    params.feedbackOutputUpperBound = 0;

    vm.expectRevert(abi.encodeWithSelector(Assertions.NullAmount.selector));

    _createPidController(IPIDController.DeviationObservation(0, 0, 0));
  }

  function test_Revert_Invalid_FeedbackOutputUpperBound(uint256 _feedbackUpperBound) public {
    vm.assume(_feedbackUpperBound > 0 && _feedbackUpperBound > POSITIVE_RATE_LIMIT);
    params.feedbackOutputUpperBound = _feedbackUpperBound;

    vm.expectRevert(
      abi.encodeWithSelector(
        Assertions.NotLesserOrEqualThan.selector, params.feedbackOutputUpperBound, POSITIVE_RATE_LIMIT
      )
    );

    _createPidController(IPIDController.DeviationObservation(0, 0, 0));
  }

  function test_Revert_FeedbackOutputLowerBoundIsGreaterThanZero(int256 _feedbackLowerBound) public {
    vm.assume(_feedbackLowerBound > 0);
    params.feedbackOutputLowerBound = _feedbackLowerBound;

    vm.expectRevert(abi.encodeWithSelector(Assertions.IntNotLesserThan.selector, _feedbackLowerBound, 0));

    _createPidController(IPIDController.DeviationObservation(0, 0, 0));
  }

  function test_Revert_Invalid_FeedbackOutputLowerBound(int256 _feedbackLowerBound) public {
    vm.assume(_feedbackLowerBound < -(int256(NEGATIVE_RATE_LIMIT)));
    params.feedbackOutputLowerBound = _feedbackLowerBound;

    vm.expectRevert(
      abi.encodeWithSelector(
        Assertions.IntNotGreaterOrEqualThan.selector, _feedbackLowerBound, -(int256(NEGATIVE_RATE_LIMIT))
      )
    );

    _createPidController(IPIDController.DeviationObservation(0, 0, 0));
  }

  function test_Revert_Invalid_IntergralPeriodSize() public {
    params.integralPeriodSize = 0;

    vm.expectRevert(abi.encodeWithSelector(Assertions.NullAmount.selector));

    _createPidController(IPIDController.DeviationObservation(0, 0, 0));
  }

  function test_Revert_NoiseBarrierIsZero() public {
    params.noiseBarrier = 0;

    vm.expectRevert(abi.encodeWithSelector(Assertions.NullAmount.selector));

    _createPidController(IPIDController.DeviationObservation(0, 0, 0));
  }

  function test_Revert_Invalid_NoiseBarrier(uint256 _noiseBarrier) public {
    vm.assume(_noiseBarrier > 0 && _noiseBarrier > WAD);
    params.noiseBarrier = _noiseBarrier;

    vm.expectRevert(abi.encodeWithSelector(Assertions.NotLesserOrEqualThan.selector, _noiseBarrier, WAD));

    _createPidController(IPIDController.DeviationObservation(0, 0, 0));
  }

  function test_Revert_Invalid_Kp(int256 _kp) public {
    vm.assume(_kp > type(int256).min && Math.absolute(_kp) > WAD);
    gains.kp = _kp;

    if (_kp < 0) {
      vm.expectRevert(abi.encodeWithSelector(Assertions.IntNotGreaterOrEqualThan.selector, _kp, -int256(WAD)));
    } else {
      vm.expectRevert(abi.encodeWithSelector(Assertions.IntNotLesserOrEqualThan.selector, _kp, int256(WAD)));
    }

    _createPidController(IPIDController.DeviationObservation(0, 0, 0));
  }

  function test_Revert_Invalid_Ki(int256 _ki) public {
    vm.assume(_ki > type(int256).min && Math.absolute(_ki) > WAD);
    gains.ki = _ki;

    if (_ki < 0) {
      vm.expectRevert(abi.encodeWithSelector(Assertions.IntNotGreaterOrEqualThan.selector, _ki, -int256(WAD)));
    } else {
      vm.expectRevert(abi.encodeWithSelector(Assertions.IntNotLesserOrEqualThan.selector, _ki, int256(WAD)));
    }

    _createPidController(IPIDController.DeviationObservation(0, 0, 0));
  }

  function test_Revert_InvalidImportedTime(uint256 _importedTime, uint256 timestamp) public {
    vm.assume(_importedTime > timestamp);
    vm.warp(timestamp);

    vm.expectRevert(abi.encodeWithSelector(Assertions.NotLesserOrEqualThan.selector, _importedTime, timestamp));

    _createPidController(IPIDController.DeviationObservation({timestamp: _importedTime, proportional: 0, integral: 0}));
  }
}

contract Unit_PIDController_TimeSinceLastUpdate is Base {
  function test_Return_Zero() public {
    assertEq(pidController.timeSinceLastUpdate(), 0);
  }

  function test_Return_TimeElapsed(uint256 _timestamp, uint256 _lastUpdate) public {
    vm.assume(_lastUpdate > 0 && _timestamp > _lastUpdate);
    vm.warp(_timestamp);
    _mockLastUpdateTime(_lastUpdate);

    assertEq(pidController.timeSinceLastUpdate(), _timestamp - _lastUpdate);
  }
}

contract Unit_PIDController_GetBoundedRedemptionRate is Base {
  using stdStorage for StdStorage;
  using Math for uint256;

  function setUp() public virtual override {
    super.setUp();
    setCallSuper(false);
    PIDControllerForTest(address(pidController)).setCallSupper_getBoundedRedemptionRate(true);
  }

  modifier negativeBoundedPIOutput(int256 _boundedPIOutput) {
    // Checks that boundedPIOutput is never less than NEGATIVE_RATE_LIMIT, the setters should prevent this
    vm.assume(_boundedPIOutput < 0 && _boundedPIOutput >= -int256(NEGATIVE_RATE_LIMIT));
    _mockBoundedPIOutput(_boundedPIOutput);
    _;
  }

  modifier positiveBoundedPIOutput(int256 _boundedPIOutput) {
    // Checks that boundedPIOutput is never greater than POSITIVE_RATE_LIMIT, the setters should prevent this
    vm.assume(_boundedPIOutput >= 0 && uint256(_boundedPIOutput) <= POSITIVE_RATE_LIMIT);
    _mockBoundedPIOutput(_boundedPIOutput);
    _;
  }

  function test_Call_Internal_GetBoundedPIOutput(int256 _piOutput) public {
    vm.expectCall(
      watcher,
      abi.encodeWithSelector(
        InternalCallsWatcher.calledInternal.selector, abi.encodeWithSignature('_getBoundedPIOutput(int256)', _piOutput)
      )
    );

    pidController.getBoundedRedemptionRate(_piOutput);
  }

  function test_Return_NewRedemptionRate_NegativeBoundedPIOutput(int256 _boundedPIOutput)
    public
    negativeBoundedPIOutput(_boundedPIOutput)
  {
    uint256 _calculatedRedemptionRate = RAY.add(_boundedPIOutput);

    // sending 0 as _piOutput because it's mocked and it does not matter
    uint256 _newRedemptionRate = pidController.getBoundedRedemptionRate(0);

    assertEq(_newRedemptionRate, _calculatedRedemptionRate);
  }

  function test_Return_NewRedemptionRate_PositiveBoundedPIOutput(int256 _boundedPIOutput)
    public
    positiveBoundedPIOutput(_boundedPIOutput)
  {
    uint256 _calculatedRedemptionRate = RAY.add(_boundedPIOutput);
    uint256 _newRedemptionRate = pidController.getBoundedRedemptionRate(0);

    assertEq(_newRedemptionRate, _calculatedRedemptionRate);
  }

  function test_Return_NewRedemptionRate_PiOutputLessThanFeedbackOutputLowerBound(int256 _piOutput) public {
    setCallSuper(true);
    vm.assume(_piOutput < -int256(NEGATIVE_RATE_LIMIT));
    uint256 _newRedemptionRate = pidController.getBoundedRedemptionRate(_piOutput);

    // RAY - NEGATIVE_RATE_LIMIT = 1
    assertEq(_newRedemptionRate, 1);
  }

  function test_Return_NewRedemptionRate_PiOutputGreaterThanFeedbackOutputUpperBound(int256 _piOutput) public {
    setCallSuper(true);
    vm.assume(_piOutput > int256(pidController.params().feedbackOutputUpperBound));
    uint256 _newRedemptionRate = pidController.getBoundedRedemptionRate(_piOutput);

    assertEq(_newRedemptionRate, RAY + pidController.params().feedbackOutputUpperBound);
  }

  // This scenario would not happen in reality because the feedbackOutputLowerBound will never be less than -NEGATIVE_RATE_LIMIT
  function test_Return_NewRedemptionRate_NEGATIVE_RATE_LIMIT(int256 _boundedPiOutput) public {
    vm.assume(_boundedPiOutput < -int256(RAY));
    _mockBoundedPIOutput(_boundedPiOutput);
    uint256 _newRedemptionRate = pidController.getBoundedRedemptionRate(0);

    assertEq(_newRedemptionRate, NEGATIVE_RATE_LIMIT);
  }
}

contract Unit_PIDController_GetNextRedemptionRate is Base {
  using stdStorage for StdStorage;
  using Math for uint256;

  struct GetNextRedemptionRateScenario {
    uint256 marketPrice;
    uint256 redemptionPrice;
    uint256 accumulatedLeak;
    int256 proportionalTerm;
    int256 cumulativeDeviation;
    int256 appliedDeviation;
    int256 piOutput;
    uint256 newRedemptionRate;
  }

  function setUp() public virtual override {
    super.setUp();

    setCallSuper(false);
    PIDControllerForTest(address(pidController)).setCallSupper_getBoundedRedemptionRate(false);
  }

  function _mockValues(GetNextRedemptionRateScenario memory _scenario, bool _breaksNoiseBarrier) internal {
    _mockGetProportionalTerm(_scenario.proportionalTerm);
    _mockGetNextDeviationCumulative(_scenario.cumulativeDeviation, _scenario.appliedDeviation);
    _mockGetGainAdjustedPIOutput(_scenario.piOutput);
    _mockBreakNoiseBarrier(_breaksNoiseBarrier);
    _mockGetBoundedRedemptionRate(_scenario.newRedemptionRate);
  }

  modifier breaksNoiseBarrier(GetNextRedemptionRateScenario memory _scenario) {
    vm.assume(_scenario.piOutput > type(int256).min && _scenario.piOutput != 0);
    _mockValues(_scenario, true);
    _;
  }

  modifier notBreaksNoiseBarrier(GetNextRedemptionRateScenario memory _scenario) {
    vm.assume(_scenario.piOutput > type(int256).min && _scenario.piOutput != 0);
    _mockValues(_scenario, false);
    _;
  }

  function test_Call_Internal_GetProportionalTerm(GetNextRedemptionRateScenario memory _scenario) public {
    vm.expectCall(
      watcher,
      abi.encodeWithSelector(
        InternalCallsWatcher.calledInternal.selector,
        abi.encodeWithSignature(
          '_getProportionalTerm(uint256,uint256)', _scenario.marketPrice, _scenario.redemptionPrice
        )
      )
    );

    pidController.getNextRedemptionRate(_scenario.marketPrice, _scenario.redemptionPrice, _scenario.accumulatedLeak);
  }

  function test_Call_Internal_GetNextDeviationCumulative(GetNextRedemptionRateScenario memory _scenario) public {
    vm.assume(_scenario.piOutput > type(int256).min);
    _mockValues(_scenario, false);

    vm.expectCall(
      watcher,
      abi.encodeWithSelector(
        InternalCallsWatcher.calledInternal.selector,
        abi.encodeWithSignature(
          '_getNextDeviationCumulative(int256,uint256)', _scenario.proportionalTerm, _scenario.accumulatedLeak
        )
      )
    );

    pidController.getNextRedemptionRate(_scenario.marketPrice, _scenario.redemptionPrice, _scenario.accumulatedLeak);
  }

  function test_Call_Internal_GetGainAdjustedPIOutput(GetNextRedemptionRateScenario memory _scenario) public {
    vm.assume(_scenario.piOutput > type(int256).min);
    _mockValues(_scenario, false);

    vm.expectCall(
      watcher,
      abi.encodeWithSelector(
        InternalCallsWatcher.calledInternal.selector,
        abi.encodeWithSignature(
          '_getGainAdjustedPIOutput(int256,int256)', _scenario.proportionalTerm, _scenario.cumulativeDeviation
        )
      )
    );

    pidController.getNextRedemptionRate(_scenario.marketPrice, _scenario.redemptionPrice, _scenario.accumulatedLeak);
  }

  function test_Call_Internal_BreaksNoiseBarrier(GetNextRedemptionRateScenario memory _scenario) public {
    PIDControllerForTest(address(pidController)).setCallSupper_getGainAdjustedPIOutput(false);
    vm.assume(_scenario.piOutput > type(int256).min);
    _mockValues(_scenario, false);

    vm.expectCall(
      watcher,
      abi.encodeWithSelector(
        InternalCallsWatcher.calledInternal.selector,
        abi.encodeWithSignature(
          '_breaksNoiseBarrier(uint256,uint256)', Math.absolute(_scenario.piOutput), _scenario.redemptionPrice
        )
      )
    );

    pidController.getNextRedemptionRate(_scenario.marketPrice, _scenario.redemptionPrice, _scenario.accumulatedLeak);
  }

  function test_Call_Internal_GetBoundedRedemptionRate_BreaksNoiseBarrier(
    GetNextRedemptionRateScenario memory _scenario
  ) public breaksNoiseBarrier(_scenario) {
    PIDControllerForTest(address(pidController)).setCallSupper_getGainAdjustedPIOutput(false);
    vm.expectCall(
      watcher,
      abi.encodeWithSelector(
        InternalCallsWatcher.calledInternal.selector,
        abi.encodeWithSignature('_getBoundedRedemptionRate(int256)', _scenario.piOutput)
      )
    );

    pidController.getNextRedemptionRate(_scenario.marketPrice, _scenario.redemptionPrice, _scenario.accumulatedLeak);
  }

  function test_Not_Call_Internal_GetBoundedRedemptionRate_NotBreaksNoiseBarrier(
    GetNextRedemptionRateScenario memory _scenario
  ) public notBreaksNoiseBarrier(_scenario) {
    vm.expectCall(
      watcher,
      abi.encodeWithSelector(
        InternalCallsWatcher.calledInternal.selector,
        abi.encodeWithSignature('_getBoundedRedemptionRate(int256)', _scenario.piOutput)
      ),
      0
    );

    pidController.getNextRedemptionRate(_scenario.marketPrice, _scenario.redemptionPrice, _scenario.accumulatedLeak);
  }

  function test_Return_BreaksNoiseBarrier(GetNextRedemptionRateScenario memory _scenario)
    public
    breaksNoiseBarrier(_scenario)
  {
    PIDControllerForTest(address(pidController)).setCallSupper_getGainAdjustedPIOutput(false);
    (uint256 _newRedemptionRate, int256 _proportionalTerm, int256 _cumulativeDeviation) =
      pidController.getNextRedemptionRate(_scenario.marketPrice, _scenario.redemptionPrice, _scenario.accumulatedLeak);

    assertEq(_newRedemptionRate, _scenario.newRedemptionRate);
    assertEq(_proportionalTerm, _scenario.proportionalTerm);
    assertEq(_cumulativeDeviation, _scenario.cumulativeDeviation);
  }

  function test_Return_NotBreaksNoiseBarrier(GetNextRedemptionRateScenario memory _scenario)
    public
    notBreaksNoiseBarrier(_scenario)
  {
    (uint256 _newRedemptionRate, int256 _proportionalTerm, int256 _cumulativeDeviation) =
      pidController.getNextRedemptionRate(_scenario.marketPrice, _scenario.redemptionPrice, _scenario.accumulatedLeak);

    assertEq(_newRedemptionRate, RAY);
    assertEq(_proportionalTerm, _scenario.proportionalTerm);
    assertEq(_cumulativeDeviation, _scenario.cumulativeDeviation);
  }
}

contract Unit_PIDController_GetProportionalTerm is Base {
  using Math for uint256;
  using Math for int256;

  modifier happyPath(uint256 _marketPrice, uint256 _redemptionPrice) {
    vm.assume(notOverflowMul(_marketPrice, 1e9));
    vm.assume(_redemptionPrice > 0);
    vm.assume(int256(_redemptionPrice) >= 0 && int256(_marketPrice * 1e9) >= 0);
    int256 _temp = _redemptionPrice.sub((_marketPrice * 1e9));
    vm.assume(type(int256).max / int256(RAY) >= int256(Math.absolute(_temp)));
    _;
  }

  function test_Return_ProportionalTerm(
    uint256 _marketPrice,
    uint256 _redemptionPrice
  ) public happyPath(_marketPrice, _redemptionPrice) {
    int256 _expectedProportionalTerm = _redemptionPrice.sub(_marketPrice * 1e9).rdiv(int256(_redemptionPrice));
    int256 _proportionalTerm =
      PIDControllerForTest(address(pidController)).call_getProportionalTerm(_marketPrice, _redemptionPrice);

    assertEq(_proportionalTerm, _expectedProportionalTerm);
  }
}

contract Unit_PIDController_BreaksNoiseBarrier is Base {
  using Math for uint256;

  modifier happyPath(uint256 _noiseBarrier, uint256 _piSum, uint256 _redemptionPrice) {
    vm.assume(uint256(2) * WAD >= _noiseBarrier);
    uint256 _deltaNoise = (uint256(2) * WAD - _noiseBarrier);
    vm.assume(notOverflowMul(_redemptionPrice, _deltaNoise));
    vm.assume(_redemptionPrice.wmul(_deltaNoise) >= _redemptionPrice);
    _mockNoiseBarrier(_noiseBarrier);
    _;
  }

  function test_Return_BreaksNoiseBarrier(
    uint256 _noiseBarrier,
    uint256 _piSum,
    uint256 _redemptionPrice
  ) public happyPath(_noiseBarrier, _piSum, _redemptionPrice) {
    bool _expectedBreaksNoiseBarrier =
      _piSum >= _redemptionPrice.wmul((uint256(2) * WAD) - _noiseBarrier) - _redemptionPrice && _piSum != 0;

    bool _breaksNoiseBarrier = pidController.breaksNoiseBarrier(_piSum, _redemptionPrice);

    assertEq(_breaksNoiseBarrier, _expectedBreaksNoiseBarrier);
  }
}

contract Unit_PID_Controller_GetGainAdjustedTerms is Base {
  using Math for int256;

  struct GetGainAdjustedTermsScenario {
    int256 proportionalTerm;
    int256 integralTerm;
    int256 kp;
    int256 ki;
  }

  modifier happyPath(GetGainAdjustedTermsScenario memory _scenario) {
    vm.assume(notOverflowMul(_scenario.kp, _scenario.proportionalTerm));
    vm.assume(notOverflowMul(_scenario.ki, _scenario.integralTerm));
    _mockControllerGains(IPIDController.ControllerGains(_scenario.kp, _scenario.ki));
    _;
  }

  function test_Return_AdjustedProportionalTerm(GetGainAdjustedTermsScenario memory _scenario)
    public
    happyPath(_scenario)
  {
    int256 _expectedProportionalTerm = _scenario.kp.wmul(_scenario.proportionalTerm);

    (int256 _gainAdjustedProportionalTerm,) =
      pidController.getGainAdjustedTerms(_scenario.proportionalTerm, _scenario.integralTerm);

    assertEq(_gainAdjustedProportionalTerm, _expectedProportionalTerm);
  }

  function test_Return_AdjustedIntegralTerm(GetGainAdjustedTermsScenario memory _scenario) public happyPath(_scenario) {
    int256 _expectedIntegralTerm = _scenario.ki.wmul(_scenario.integralTerm);

    (, int256 _gainAdjustedIntegralTerm) =
      pidController.getGainAdjustedTerms(_scenario.proportionalTerm, _scenario.integralTerm);

    assertEq(_gainAdjustedIntegralTerm, _expectedIntegralTerm);
  }
}

contract Unit_PID_Controller_GetGainAdjustedPIOutput is Base {
  function setUp() public virtual override {
    super.setUp();
    setCallSuper(false);
    PIDControllerForTest(address(pidController)).setCallSupper_getGainAdjustedPIOutput(true);
  }

  struct GetGainAdjustedPIOutput {
    int256 proportionalTerm;
    int256 integralTerm;
    int256 adjustedProportionalTerm;
    int256 adjustedIntegralTerm;
  }

  modifier happyPath(GetGainAdjustedPIOutput memory _scenario) {
    vm.assume(notOverflowAdd(_scenario.adjustedProportionalTerm, _scenario.adjustedIntegralTerm));
    _mockGetGainAdjustedTerms(_scenario.adjustedProportionalTerm, _scenario.adjustedIntegralTerm);
    _;
  }

  function test_Call_Internal_GetGainAdjusted_Terms(GetGainAdjustedPIOutput memory _scenario) public {
    vm.expectCall(
      watcher,
      abi.encodeCall(
        InternalCallsWatcher.calledInternal,
        abi.encodeWithSignature(
          '_getGainAdjustedTerms(int256,int256)', _scenario.proportionalTerm, _scenario.integralTerm
        )
      )
    );

    pidController.getGainAdjustedPIOutput(_scenario.proportionalTerm, _scenario.integralTerm);
  }

  function test_Return_AdjustedPIOutput(GetGainAdjustedPIOutput memory _scenario) public happyPath(_scenario) {
    int256 _expectedAdjustedPIOutput = _scenario.adjustedProportionalTerm + _scenario.adjustedIntegralTerm;

    assertEq(
      _expectedAdjustedPIOutput,
      pidController.getGainAdjustedPIOutput(_scenario.proportionalTerm, _scenario.integralTerm)
    );
  }
}

contract Unit_PIDController_GetNextDeviationCumulative is Base {
  using Math for int256;
  using Math for uint256;

  function setUp() public virtual override {
    super.setUp();
    setCallSuper(false);
    PIDControllerForTest(address(pidController)).setCallSupper_getNextDeviationCumulative(true);
  }

  struct GetNextDeviationCumulativeScenario {
    int256 lastProportionalTerm;
    uint256 lastUpdateTime;
    int256 priceDeviationCumulative;
    uint256 timestamp;
    int256 proportionalTerm;
    uint256 accumulatedLeak;
  }

  function _happyPath(GetNextDeviationCumulativeScenario memory _scenario) internal pure {
    vm.assume(_scenario.timestamp >= _scenario.lastUpdateTime);
    vm.assume(_scenario.timestamp - _scenario.lastUpdateTime <= uint256(type(int256).max));
    vm.assume(_scenario.accumulatedLeak <= uint256(type(int256).max));
    vm.assume(notOverflowAdd(_scenario.proportionalTerm, _scenario.lastProportionalTerm));
    vm.assume(
      notOverflowMul(
        (_scenario.proportionalTerm + _scenario.lastProportionalTerm) / 2,
        int256(_scenario.timestamp - _scenario.lastUpdateTime)
      )
    );
    vm.assume(notOverflowMul(int256(_scenario.accumulatedLeak), _scenario.priceDeviationCumulative));
    vm.assume(
      notOverflowAdd(
        int256(_scenario.accumulatedLeak.rmul(_scenario.priceDeviationCumulative)),
        ((_scenario.proportionalTerm + _scenario.lastProportionalTerm) / 2)
          * int256(_scenario.timestamp - _scenario.lastUpdateTime)
      )
    );
  }

  modifier lastUpdateTimeNotZero(GetNextDeviationCumulativeScenario memory _scenario) {
    vm.assume(_scenario.lastUpdateTime > 0);
    _happyPath(_scenario);
    _mockValues(_scenario);
    _;
  }

  modifier lastUpdateTimeIsZero(GetNextDeviationCumulativeScenario memory _scenario) {
    _scenario.lastUpdateTime = 0;
    _happyPath(_scenario);
    _mockValues(_scenario);
    _;
  }

  function _mockValues(GetNextDeviationCumulativeScenario memory _scenario) internal {
    _mockLastUpdateTime(_scenario.lastUpdateTime);
    _mockProportionalTerm(_scenario.lastProportionalTerm);
    _mockIntegralTerm(_scenario.priceDeviationCumulative);
    vm.warp(_scenario.timestamp);
  }

  function test_Return_NextDeviationCumulative(GetNextDeviationCumulativeScenario memory _scenario)
    public
    lastUpdateTimeNotZero(_scenario)
  {
    int256 _expectedNewTimeAdjustedDeviation = ((_scenario.proportionalTerm + _scenario.lastProportionalTerm) / 2)
      * int256(_scenario.timestamp - _scenario.lastUpdateTime);
    int256 _expectedNextDeviationCumulative =
      _scenario.accumulatedLeak.rmul(_scenario.priceDeviationCumulative) + _expectedNewTimeAdjustedDeviation;

    (int256 _nextDeviationCumulative,) =
      pidController.getNextDeviationCumulative(_scenario.proportionalTerm, _scenario.accumulatedLeak);

    assertEq(_nextDeviationCumulative, _expectedNextDeviationCumulative);
  }

  function test_Return_NewTimeAdjustedDeviation(GetNextDeviationCumulativeScenario memory _scenario)
    public
    lastUpdateTimeNotZero(_scenario)
  {
    int256 _expectedNewTimeAdjustedDeviation = ((_scenario.proportionalTerm + _scenario.lastProportionalTerm) / 2)
      * int256(_scenario.timestamp - _scenario.lastUpdateTime);

    (, int256 _newTimeAdjustedDeviation) =
      pidController.getNextDeviationCumulative(_scenario.proportionalTerm, _scenario.accumulatedLeak);

    assertEq(_newTimeAdjustedDeviation, _expectedNewTimeAdjustedDeviation);
  }

  function test_Return_NextDeviationCumulative_LastUpdateIsZero(GetNextDeviationCumulativeScenario memory _scenario)
    public
    lastUpdateTimeIsZero(_scenario)
  {
    int256 _expectedNextDeviationCumulative = _scenario.accumulatedLeak.rmul(_scenario.priceDeviationCumulative);

    (int256 _nextDeviationCumulative,) =
      pidController.getNextDeviationCumulative(_scenario.proportionalTerm, _scenario.accumulatedLeak);

    assertEq(_nextDeviationCumulative, _expectedNextDeviationCumulative);
  }

  function test_Return_NewTimeAdjustedDeviation_LastUpdateIsZero(GetNextDeviationCumulativeScenario memory _scenario)
    public
    lastUpdateTimeIsZero(_scenario)
  {
    (, int256 _newTimeAdjustedDeviation) =
      pidController.getNextDeviationCumulative(_scenario.proportionalTerm, _scenario.accumulatedLeak);

    assertEq(_newTimeAdjustedDeviation, 0);
  }
}

contract Unit_PIDController_UpdateDeviation is Base {
  function setUp() public virtual override {
    super.setUp();
    setCallSuper(false);
    PIDControllerForTest(address(pidController)).setCallSupper_updateDeviation(true);
  }

  struct UpdateDeviationScenario {
    int256 virtualDeviationCumulative;
    int256 appliedDeviation;
    uint256 timestamp;
    int256 proportionalTerm;
    uint256 accumulatedLeak;
  }

  function test_Call_Internal_GetNextDeviationCumulative(UpdateDeviationScenario memory _scenario) public {
    vm.expectCall(
      watcher,
      abi.encodeCall(
        InternalCallsWatcher.calledInternal,
        abi.encodeWithSignature(
          '_getNextDeviationCumulative(int256,uint256)', _scenario.proportionalTerm, _scenario.accumulatedLeak
        )
      )
    );

    PIDControllerForTest(address(pidController)).call_updateDeviation(
      _scenario.proportionalTerm, _scenario.accumulatedLeak
    );
  }

  function test_Set_DeviationCumulative(UpdateDeviationScenario memory _scenario) public {
    _mockGetNextDeviationCumulative(_scenario.virtualDeviationCumulative, _scenario.appliedDeviation);

    PIDControllerForTest(address(pidController)).call_updateDeviation(
      _scenario.proportionalTerm, _scenario.accumulatedLeak
    );

    assertEq(pidController.deviationObservation().integral, _scenario.virtualDeviationCumulative);
  }

  function test_Set_DeviationObservation(UpdateDeviationScenario memory _scenario) public {
    _mockGetNextDeviationCumulative(_scenario.virtualDeviationCumulative, _scenario.appliedDeviation);
    vm.warp(_scenario.timestamp);

    PIDControllerForTest(address(pidController)).call_updateDeviation(
      _scenario.proportionalTerm, _scenario.accumulatedLeak
    );

    IPIDController.DeviationObservation memory _deviation = pidController.deviationObservation();
    bytes memory _expectedResult =
      abi.encode(_scenario.timestamp, _scenario.proportionalTerm, _scenario.virtualDeviationCumulative);

    assertEq(abi.encode(_deviation.timestamp, _deviation.proportional, _deviation.integral), _expectedResult);
  }

  event UpdateDeviation(int256 _proportionalDeviation, int256 _cumulativeDeviation, int256 _deltaCumulativeDeviation);

  function test_Emit_UpdateDeviation(UpdateDeviationScenario memory _scenario) public {
    _mockGetNextDeviationCumulative(_scenario.virtualDeviationCumulative, _scenario.appliedDeviation);
    vm.warp(_scenario.timestamp);

    vm.expectEmit();
    emit UpdateDeviation({
      _proportionalDeviation: _scenario.proportionalTerm,
      _cumulativeDeviation: _scenario.virtualDeviationCumulative,
      _deltaCumulativeDeviation: _scenario.appliedDeviation
    });

    PIDControllerForTest(address(pidController)).call_updateDeviation(
      _scenario.proportionalTerm, _scenario.accumulatedLeak
    );
  }
}

contract Unit_PIDController_ComputeRate is Base {
  using Math for int256;
  using Math for uint256;

  function setUp() public virtual override {
    super.setUp();

    setCallSuper(false);
    PIDControllerForTest(address(pidController)).setCallSupper_updateDeviation(true);
    PIDControllerForTest(address(pidController)).setCallSupper_getBoundedRedemptionRate(false);
    PIDControllerForTest(address(pidController)).setCallSupper_getGainAdjustedPIOutput(false);
  }

  struct ComputeRateScenario {
    uint256 timestamp;
    // PIDController params
    uint256 integralPeriodSize;
    uint256 lastUpdateTime;
    uint256 perSecondCumulativeLeak;
    // Internal functions returns
    int256 proportionalTerm;
    int256 priceDeviationCumulative;
    int256 appliedDeviation;
    int256 piOutput;
    uint256 newRedemptionRate;
    // Function params
    uint256 marketPrice;
    uint256 redemptionPrice;
  }

  function _happyPath(ComputeRateScenario memory _scenario) internal view {
    vm.assume(_scenario.lastUpdateTime > 0);
    vm.assume(_scenario.timestamp >= _scenario.lastUpdateTime);
    vm.assume(_scenario.timestamp - _scenario.lastUpdateTime >= _scenario.integralPeriodSize);
    vm.assume(_scenario.piOutput != 0);
    vm.assume(_scenario.piOutput > type(int256).min);
    vm.assume(notOverflowRPow(_scenario.perSecondCumulativeLeak, _scenario.timestamp - _scenario.lastUpdateTime));
  }

  function _mockValues(ComputeRateScenario memory _scenario, bool _breaksNoiseBarrier) internal {
    vm.warp(_scenario.timestamp);
    _mockGetProportionalTerm(_scenario.proportionalTerm);
    _mockPerSecondCumulativeLeak(_scenario.perSecondCumulativeLeak);
    _mockGetNextDeviationCumulative(_scenario.priceDeviationCumulative, _scenario.appliedDeviation);
    _mockGetGainAdjustedPIOutput(_scenario.piOutput);
    _mockBreakNoiseBarrier(_breaksNoiseBarrier);
    _mockLastUpdateTime(_scenario.lastUpdateTime);
    _mockIntegralPeriodSize(_scenario.integralPeriodSize);
    _mockGetBoundedRedemptionRate(_scenario.newRedemptionRate);
    PIDControllerForTest(address(pidController)).setSeedProposer(deployer);
  }

  modifier happyPath(ComputeRateScenario memory _scenario, bool _breaksNoiseBarrier) {
    _happyPath(_scenario);
    _mockValues(_scenario, _breaksNoiseBarrier);
    _;
  }

  modifier notBreaksNoiseBarrier(ComputeRateScenario memory _scenario) {
    _happyPath(_scenario);
    _mockValues(_scenario, false);
    _;
  }

  modifier breaksNoiseBarrier(ComputeRateScenario memory _scenario) {
    _happyPath(_scenario);
    _mockValues(_scenario, true);
    _;
  }

  function test_Call_Internal_GetProportionalTerm(ComputeRateScenario memory _scenario)
    public
    breaksNoiseBarrier(_scenario)
    authorized
  {
    vm.expectCall(
      watcher,
      abi.encodeCall(
        InternalCallsWatcher.calledInternal,
        abi.encodeWithSignature(
          '_getProportionalTerm(uint256,uint256)', _scenario.marketPrice, _scenario.redemptionPrice
        )
      )
    );

    pidController.computeRate(_scenario.marketPrice, _scenario.redemptionPrice);
  }

  function test_Call_Internal_UpdateDeviation(ComputeRateScenario memory _scenario)
    public
    breaksNoiseBarrier(_scenario)
    authorized
  {
    vm.expectCall(
      watcher,
      abi.encodeCall(
        InternalCallsWatcher.calledInternal,
        abi.encodeWithSignature(
          '_updateDeviation(int256,uint256)',
          _scenario.proportionalTerm,
          _scenario.perSecondCumulativeLeak.rpow(_scenario.timestamp - _scenario.lastUpdateTime)
        )
      )
    );

    pidController.computeRate(_scenario.marketPrice, _scenario.redemptionPrice);
  }

  function test_Call_Internal_UpdateDeviation_FirstUpdate(
    ComputeRateScenario memory _scenario,
    bool _breaksNoiseBarrier
  ) public authorized {
    _happyPath(_scenario);
    _scenario.lastUpdateTime = 0;
    _mockValues(_scenario, _breaksNoiseBarrier);

    vm.expectCall(
      watcher,
      abi.encodeCall(
        InternalCallsWatcher.calledInternal,
        abi.encodeWithSignature('_updateDeviation(int256,uint256)', _scenario.proportionalTerm, RAY)
      )
    );

    pidController.computeRate(_scenario.marketPrice, _scenario.redemptionPrice);
  }

  function test_Call_Internal_GetGainAdjustedOutput(
    ComputeRateScenario memory _scenario,
    bool _breaksNoiseBarrier
  ) public happyPath(_scenario, _breaksNoiseBarrier) authorized {
    vm.expectCall(
      watcher,
      abi.encodeCall(
        InternalCallsWatcher.calledInternal,
        abi.encodeWithSignature(
          '_getGainAdjustedPIOutput(int256,int256)', _scenario.proportionalTerm, _scenario.priceDeviationCumulative
        )
      )
    );

    pidController.computeRate(_scenario.marketPrice, _scenario.redemptionPrice);
  }

  function test_Call_Internal_BreaksNoiseBarrier(
    ComputeRateScenario memory _scenario,
    bool _breaksNoiseBarrier
  ) public happyPath(_scenario, _breaksNoiseBarrier) authorized {
    vm.expectCall(
      watcher,
      abi.encodeCall(
        InternalCallsWatcher.calledInternal,
        abi.encodeWithSignature(
          '_breaksNoiseBarrier(uint256,uint256)', Math.absolute(_scenario.piOutput), _scenario.redemptionPrice
        )
      )
    );

    pidController.computeRate(_scenario.marketPrice, _scenario.redemptionPrice);
  }

  function test_Call_Internal_GetBoundedRedemptionRate(ComputeRateScenario memory _scenario)
    public
    breaksNoiseBarrier(_scenario)
    authorized
  {
    vm.expectCall(
      watcher,
      abi.encodeCall(
        InternalCallsWatcher.calledInternal,
        abi.encodeWithSignature('_getBoundedRedemptionRate(int256)', _scenario.piOutput)
      )
    );

    pidController.computeRate(_scenario.marketPrice, _scenario.redemptionPrice);
  }

  function test_Not_Call_Internal_GetBoundedRedemptionRate_NotBreaksNoiseBarrier(ComputeRateScenario memory _scenario)
    public
    notBreaksNoiseBarrier(_scenario)
    authorized
  {
    vm.expectCall(
      watcher,
      abi.encodeCall(
        InternalCallsWatcher.calledInternal,
        abi.encodeWithSignature('_getBoundedRedemptionRate(int256)', _scenario.piOutput)
      ),
      0
    );

    pidController.computeRate(_scenario.marketPrice, _scenario.redemptionPrice);
  }

  function test_Return_RAY_NotBreaksNoiseBarrier(ComputeRateScenario memory _scenario)
    public
    notBreaksNoiseBarrier(_scenario)
    authorized
  {
    assertEq(pidController.computeRate(_scenario.marketPrice, _scenario.redemptionPrice), RAY);
  }

  function test_Return_NewRedemptionRate(ComputeRateScenario memory _scenario)
    public
    breaksNoiseBarrier(_scenario)
    authorized
  {
    assertEq(pidController.computeRate(_scenario.marketPrice, _scenario.redemptionPrice), _scenario.newRedemptionRate);
  }

  function test_Set_Deviation(ComputeRateScenario memory _scenario) public notBreaksNoiseBarrier(_scenario) authorized {
    pidController.computeRate(_scenario.marketPrice, _scenario.redemptionPrice);
    assertEq(pidController.deviationObservation().timestamp, block.timestamp);
    assertEq(pidController.deviationObservation().proportional, _scenario.proportionalTerm);
    assertEq(pidController.deviationObservation().integral, _scenario.priceDeviationCumulative);
  }

  function test_Revert_OnlySeedProposer(
    ComputeRateScenario memory _scenario,
    address _user
  ) public breaksNoiseBarrier(_scenario) {
    vm.assume(_user != deployer);

    vm.expectRevert(IPIDController.PIDController_OnlySeedProposer.selector);

    vm.prank(_user);
    pidController.computeRate(_scenario.marketPrice, _scenario.redemptionPrice);
  }

  function test_Revert_WaitMore(ComputeRateScenario memory _scenario) public authorized {
    vm.assume(_scenario.lastUpdateTime > 0);
    vm.assume(_scenario.timestamp >= _scenario.lastUpdateTime);
    vm.assume(_scenario.timestamp - _scenario.lastUpdateTime < _scenario.integralPeriodSize);
    _mockValues(_scenario, true);

    vm.expectRevert(IPIDController.PIDController_ComputeRateCooldown.selector);

    pidController.computeRate(_scenario.marketPrice, _scenario.redemptionPrice);
  }
}

contract Unit_PIDController_GetBoundedPIOutput is Base {
  function _mockValues(int256 _feedbackOutputLowerBound, uint256 _feedbackOutputUpperBound) internal {
    _mockFeedbackOutputUpperBound(_feedbackOutputUpperBound);
    _mockFeedbackOutputLowerBound(_feedbackOutputLowerBound);
  }

  function _happyPath(int256 _feedbackOutputLowerBound, uint256 _feedbackOutputUpperBound) internal pure {
    vm.assume(_feedbackOutputUpperBound <= uint256(type(int256).max));
    vm.assume(_feedbackOutputLowerBound > type(int256).min);
    vm.assume(_feedbackOutputUpperBound >= uint256(_feedbackOutputLowerBound));
  }

  modifier inBounds(int256 _piOutput, int256 _feedbackOutputLowerBound, uint256 _feedbackOutputUpperBound) {
    _happyPath(_feedbackOutputLowerBound, _feedbackOutputUpperBound);
    vm.assume(_piOutput >= _feedbackOutputLowerBound);
    vm.assume(_piOutput <= int256(_feedbackOutputUpperBound));
    _mockValues(_feedbackOutputLowerBound, _feedbackOutputUpperBound);
    _;
  }

  modifier exceedsUpperBound(int256 _piOutput, int256 _feedbackOutputLowerBound, uint256 _feedbackOutputUpperBound) {
    _happyPath(_feedbackOutputLowerBound, _feedbackOutputUpperBound);
    vm.assume(_piOutput > int256(_feedbackOutputUpperBound));
    _mockValues(_feedbackOutputLowerBound, _feedbackOutputUpperBound);
    _;
  }

  modifier lessThanLowerBound(int256 _piOutput, int256 _feedbackOutputLowerBound, uint256 _feedbackOutputUpperBound) {
    _happyPath(_feedbackOutputLowerBound, _feedbackOutputUpperBound);
    vm.assume(_piOutput < _feedbackOutputLowerBound);
    _mockValues(_feedbackOutputLowerBound, _feedbackOutputUpperBound);
    _;
  }

  function test_Return_PIOutput(
    int256 _piOutput,
    int256 _feedbackOutputLowerBound,
    uint256 _feedbackOutputUpperBound
  ) public inBounds(_piOutput, _feedbackOutputLowerBound, _feedbackOutputUpperBound) {
    assertEq(PIDControllerForTest(address(pidController)).call_getBoundedPIOutput(_piOutput), _piOutput);
  }

  function test_Return_UpperBound(
    int256 _piOutput,
    int256 _feedbackOutputLowerBound,
    uint256 _feedbackOutputUpperBound
  ) public exceedsUpperBound(_piOutput, _feedbackOutputLowerBound, _feedbackOutputUpperBound) {
    assertEq(
      PIDControllerForTest(address(pidController)).call_getBoundedPIOutput(_piOutput), int256(_feedbackOutputUpperBound)
    );
  }

  function test_Return_LowerBound(
    int256 _piOutput,
    int256 _feedbackOutputLowerBound,
    uint256 _feedbackOutputUpperBound
  ) public lessThanLowerBound(_piOutput, _feedbackOutputLowerBound, _feedbackOutputUpperBound) {
    assertEq(PIDControllerForTest(address(pidController)).call_getBoundedPIOutput(_piOutput), _feedbackOutputLowerBound);
  }
}

contract Unit_PIDController_ControllerGains is Base {
  function test_Return_ControllerGains_Kp(int256 _proportionalGain, int256 _integralGain) public {
    _mockControllerGains(IPIDController.ControllerGains(_proportionalGain, _integralGain));

    assertEq(pidController.controllerGains().kp, _proportionalGain);
  }

  function test_Return_ControllerGains_Ki(int256 _proportionalGain, int256 _integralGain) public {
    _mockControllerGains(IPIDController.ControllerGains(_proportionalGain, _integralGain));

    assertEq(pidController.controllerGains().ki, _integralGain);
  }
}

contract Unit_PIDController_ModifyParameters is Base {
  function test_ModifyParameters(
    address _fuzzSeedProposer,
    IPIDController.PIDControllerParams memory _fuzz,
    IPIDController.ControllerGains memory _fuzzGains
  ) public authorized {
    vm.assume(_fuzzSeedProposer != address(0));
    vm.assume(_fuzz.noiseBarrier > 0 && _fuzz.noiseBarrier <= WAD);
    vm.assume(_fuzz.integralPeriodSize > 0);
    vm.assume(_fuzz.feedbackOutputUpperBound > 0 && _fuzz.feedbackOutputUpperBound < POSITIVE_RATE_LIMIT);
    vm.assume(_fuzz.feedbackOutputLowerBound > -int256(NEGATIVE_RATE_LIMIT) && _fuzz.feedbackOutputLowerBound < 0);
    vm.assume(_fuzz.perSecondCumulativeLeak <= RAY);
    vm.assume(_fuzzGains.kp >= -int256(WAD) && _fuzzGains.kp <= int256(WAD));
    vm.assume(_fuzzGains.ki >= -int256(WAD) && _fuzzGains.ki <= int256(WAD));

    pidController.modifyParameters('seedProposer', abi.encode(_fuzzSeedProposer));
    pidController.modifyParameters('noiseBarrier', abi.encode(_fuzz.noiseBarrier));
    pidController.modifyParameters('integralPeriodSize', abi.encode(_fuzz.integralPeriodSize));
    pidController.modifyParameters('feedbackOutputUpperBound', abi.encode(_fuzz.feedbackOutputUpperBound));
    pidController.modifyParameters('feedbackOutputLowerBound', abi.encode(_fuzz.feedbackOutputLowerBound));
    pidController.modifyParameters('perSecondCumulativeLeak', abi.encode(_fuzz.perSecondCumulativeLeak));
    pidController.modifyParameters('kp', abi.encode(_fuzzGains.kp));
    pidController.modifyParameters('ki', abi.encode(_fuzzGains.ki));

    address _seedProposer = pidController.seedProposer();
    IPIDController.PIDControllerParams memory _params = pidController.params();
    IPIDController.ControllerGains memory _controllerGains = pidController.controllerGains();

    assertEq(_fuzzSeedProposer, _seedProposer);
    assertEq(abi.encode(_fuzz), abi.encode(_params));
    assertEq(abi.encode(_fuzzGains), abi.encode(_controllerGains));
  }

  function test_Set_PriceDeviationCumulative(
    int256 _proportionalGain,
    uint256 _priceDeviationCumulative
  ) public authorized {
    vm.assume(_proportionalGain >= -int256(WAD) && _proportionalGain <= int256(WAD));
    _mockControllerGains(IPIDController.ControllerGains(_proportionalGain, 0));
    pidController.modifyParameters('priceDeviationCumulative', abi.encode(_priceDeviationCumulative));

    assertEq(pidController.deviationObservation().integral, int256(_priceDeviationCumulative));
  }

  function test_Revert_NullSeedProposer() public authorized {
    vm.expectRevert(Assertions.NullAddress.selector);

    pidController.modifyParameters('seedProposer', abi.encode(address(0)));
  }

  function test_Revert_InvalidNoiseBarrier(uint256 _noiseBarrier) public authorized {
    if (_noiseBarrier == 0) {
      vm.expectRevert(Assertions.NullAmount.selector);
    } else if (_noiseBarrier > WAD) {
      vm.expectRevert(abi.encodeWithSelector(Assertions.NotLesserOrEqualThan.selector, _noiseBarrier, WAD));
    }

    pidController.modifyParameters('noiseBarrier', abi.encode(_noiseBarrier));
  }

  function test_Revert_InvalidIntegralPeriodSize() public authorized {
    vm.expectRevert(Assertions.NullAmount.selector);

    pidController.modifyParameters('integralPeriodSize', abi.encode(0));
  }

  function test_Revert_InvalidFeedbackOutputUpperBound(uint256 _feedbackOutputUpperBound) public authorized {
    if (_feedbackOutputUpperBound == 0) {
      vm.expectRevert(Assertions.NullAmount.selector);
    } else if (_feedbackOutputUpperBound > POSITIVE_RATE_LIMIT) {
      vm.expectRevert(
        abi.encodeWithSelector(Assertions.NotLesserOrEqualThan.selector, _feedbackOutputUpperBound, POSITIVE_RATE_LIMIT)
      );
    }

    pidController.modifyParameters('feedbackOutputUpperBound', abi.encode(_feedbackOutputUpperBound));
  }

  function test_Revert_FeedbackOutputLowerBound(int256 _feedbackOutputLowerBound) public authorized {
    if (_feedbackOutputLowerBound >= 0) {
      vm.expectRevert(abi.encodeWithSelector(Assertions.IntNotLesserThan.selector, _feedbackOutputLowerBound, 0));
    } else if (_feedbackOutputLowerBound < -int256(NEGATIVE_RATE_LIMIT)) {
      vm.expectRevert(
        abi.encodeWithSelector(
          Assertions.IntNotGreaterOrEqualThan.selector, _feedbackOutputLowerBound, -int256(NEGATIVE_RATE_LIMIT)
        )
      );
    }

    pidController.modifyParameters('feedbackOutputLowerBound', abi.encode(_feedbackOutputLowerBound));
  }

  function test_Revert_InvalidPerSecondCumulativeLeak(uint256 _perSecondCumulativeLeak) public authorized {
    if (_perSecondCumulativeLeak > RAY) {
      vm.expectRevert(abi.encodeWithSelector(Assertions.NotLesserOrEqualThan.selector, _perSecondCumulativeLeak, RAY));
    }

    pidController.modifyParameters('perSecondCumulativeLeak', abi.encode(_perSecondCumulativeLeak));
  }

  function test_Revert_InvalidProportionalGain(int256 _proportionalGain) public authorized {
    if (_proportionalGain > int256(WAD)) {
      vm.expectRevert(
        abi.encodeWithSelector(Assertions.IntNotLesserOrEqualThan.selector, _proportionalGain, int256(WAD))
      );
    } else if (_proportionalGain < -int256(WAD)) {
      vm.expectRevert(
        abi.encodeWithSelector(Assertions.IntNotGreaterOrEqualThan.selector, _proportionalGain, -int256(WAD))
      );
    }

    pidController.modifyParameters('kp', abi.encode(_proportionalGain));
  }

  function test_Revert_InvalidIntegralGain(int256 _integralGain) public authorized {
    if (_integralGain > int256(WAD)) {
      vm.expectRevert(abi.encodeWithSelector(Assertions.IntNotLesserOrEqualThan.selector, _integralGain, int256(WAD)));
    } else if (_integralGain < -int256(WAD)) {
      vm.expectRevert(abi.encodeWithSelector(Assertions.IntNotGreaterOrEqualThan.selector, _integralGain, -int256(WAD)));
    }

    pidController.modifyParameters('ki', abi.encode(_integralGain));
  }

  function test_Revert_PriceDeviationCumulative(
    IPIDController.ControllerGains memory _gains,
    uint256 _priceDeviationCumulative
  ) public authorized {
    vm.assume(_gains.ki != 0); // turn on the integral gain
    _mockControllerGains(_gains);

    vm.expectRevert(IPIDController.PIDController_CannotSetPriceDeviationCumulative.selector);

    pidController.modifyParameters('priceDeviationCumulative', abi.encode(_priceDeviationCumulative));
  }
}
