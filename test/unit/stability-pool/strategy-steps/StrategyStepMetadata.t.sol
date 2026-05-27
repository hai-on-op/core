// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {HaiTest} from '@test/utils/HaiTest.t.sol';
import {IStrategyStep} from '@interfaces/IStrategyStep.sol';

import {BalancerV3StablePoolMathSwapStep} from
  '@contracts/stability-pool/strategy-steps/BalancerV3StablePoolMathSwapStep.sol';
import {BeefyVaultWithdrawalStep} from '@contracts/stability-pool/strategy-steps/BeefyVaultWithdrawalStep.sol';
import {CurveSwapStep} from '@contracts/stability-pool/strategy-steps/CurveSwapStep.sol';
import {ERC4626WithdrawalStep} from '@contracts/stability-pool/strategy-steps/ERC4626WithdrawalStep.sol';
import {VeloCLSwapStepViewQuoter} from '@contracts/stability-pool/strategy-steps/VeloCLSwapStepViewQuoter.sol';
import {VeloLPRemovalStep} from '@contracts/stability-pool/strategy-steps/VeloLPRemovalStep.sol';
import {VeloLPRemoveAndSwapStep} from '@contracts/stability-pool/strategy-steps/VeloLPRemoveAndSwapStep.sol';
import {VeloSwapStep} from '@contracts/stability-pool/strategy-steps/VeloSwapStep.sol';
import {YearnVaultWithdrawalStep} from '@contracts/stability-pool/strategy-steps/YearnVaultWithdrawalStep.sol';

abstract contract Base is HaiTest {
  uint256 internal constant DEFAULT_MAX_QUOTE_STEPS = 4096;

  address internal constant ROUTER = address(0x1001);
  address internal constant POOL = address(0x1002);
  address internal constant FACTORY = address(0x1003);
  address internal constant VAULT = address(0x1004);
  address internal constant LP_TOKEN = address(0x1005);
  address internal constant TOKEN_IN = address(0x1006);
  address internal constant TOKEN_OUT = address(0x1007);
  address internal constant TOKEN_A = address(0x1008);
  address internal constant TOKEN_B = address(0x1009);

  BalancerV3StablePoolMathSwapStep internal balancerStep;
  BeefyVaultWithdrawalStep internal beefyStep;
  CurveSwapStep internal curveStep;
  ERC4626WithdrawalStep internal erc4626Step;
  VeloCLSwapStepViewQuoter internal veloClStep;
  VeloLPRemovalStep internal veloLpRemovalStep;
  VeloLPRemoveAndSwapStep internal veloLpRemoveAndSwapStep;
  VeloSwapStep internal veloSwapStep;
  YearnVaultWithdrawalStep internal yearnStep;

  function setUp() public virtual {
    balancerStep = new BalancerV3StablePoolMathSwapStep();
    beefyStep = new BeefyVaultWithdrawalStep();
    curveStep = new CurveSwapStep();
    erc4626Step = new ERC4626WithdrawalStep();
    veloClStep = new VeloCLSwapStepViewQuoter(DEFAULT_MAX_QUOTE_STEPS);
    veloLpRemovalStep = new VeloLPRemovalStep();
    veloLpRemoveAndSwapStep = new VeloLPRemoveAndSwapStep();
    veloSwapStep = new VeloSwapStep();
    yearnStep = new YearnVaultWithdrawalStep();
  }

  function _assertSingleOutputMetadata(
    IStrategyStep _step,
    bytes memory _data,
    bytes32 _expectedStepType,
    address _expectedInput,
    address _expectedOutput
  ) internal pure {
    assertEq(_step.stepType(), _expectedStepType);
    assertEq(_step.inputToken(_data), _expectedInput);
    address[] memory _outputs = _step.outputTokens(_data);
    assertEq(_outputs.length, 1);
    assertEq(_outputs[0], _expectedOutput);
  }
}

contract Unit_StrategyStep_Metadata is Base {
  function test_Balancer_Metadata() public view {
    bytes memory _data = abi.encode(
      BalancerV3StablePoolMathSwapStep.Data({
        router: ROUTER,
        pool: POOL,
        tokenIn: TOKEN_IN,
        tokenOut: TOKEN_OUT,
        deadlineBuffer: 1 hours,
        userData: bytes(''),
        useOracleFloor: true,
        tokenInOracle: address(0),
        tokenOutOracle: address(0),
        oracleToleranceBps: 0
      })
    );
    _assertSingleOutputMetadata(balancerStep, _data, bytes32('BALANCER_V3_SWAP'), TOKEN_IN, TOKEN_OUT);
  }

  function test_Beefy_Metadata() public view {
    bytes memory _data = abi.encode(
      BeefyVaultWithdrawalStep.Data({vault: VAULT, vaultToken: LP_TOKEN, lpToken: TOKEN_OUT, shareScale: 1e18})
    );
    _assertSingleOutputMetadata(beefyStep, _data, bytes32('BEEFY_WITHDRAW'), LP_TOKEN, TOKEN_OUT);
  }

  function test_Curve_Metadata() public view {
    bytes memory _data = abi.encode(
      CurveSwapStep.Data({
        pool: POOL,
        i: int128(0),
        j: int128(1),
        tokenIn: TOKEN_IN,
        tokenOut: TOKEN_OUT,
        useOracleFloor: true,
        tokenInOracle: address(1),
        tokenOutOracle: address(2),
        oracleToleranceBps: 0
      })
    );
    _assertSingleOutputMetadata(curveStep, _data, bytes32('CURVE_SWAP'), TOKEN_IN, TOKEN_OUT);
  }

  function test_ERC4626_Metadata() public view {
    bytes memory _data =
      abi.encode(ERC4626WithdrawalStep.Data({vault: VAULT, vaultToken: LP_TOKEN, assetToken: TOKEN_OUT}));
    _assertSingleOutputMetadata(erc4626Step, _data, bytes32('ERC4626_WITHDRAW'), LP_TOKEN, TOKEN_OUT);
  }

  function test_VeloCL_Metadata() public view {
    bytes memory _data = abi.encode(
      VeloCLSwapStepViewQuoter.Data({
        router: ROUTER,
        pool: POOL,
        tokenIn: TOKEN_IN,
        tokenOut: TOKEN_OUT,
        tickSpacing: 60,
        sqrtPriceLimitX96: 0,
        deadlineBuffer: 1 hours,
        useOracleFloor: false,
        tokenInOracle: address(0),
        tokenOutOracle: address(0),
        oracleToleranceBps: 0
      })
    );
    _assertSingleOutputMetadata(veloClStep, _data, bytes32('VELO_CL_SWAP'), TOKEN_IN, TOKEN_OUT);
  }

  function test_VeloLPRemoval_Metadata() public view {
    bytes memory _data = abi.encode(
      VeloLPRemovalStep.Data({
        router: ROUTER,
        lpToken: LP_TOKEN,
        tokenA: TOKEN_A,
        tokenB: TOKEN_B,
        stable: false,
        deadlineBuffer: 1 hours,
        useOracleFloor: false,
        tokenAOracle: address(0),
        tokenBOracle: address(0),
        oracleToleranceBps: 0
      })
    );
    assertEq(veloLpRemovalStep.stepType(), bytes32('VELO_LP_REMOVE'));
    assertEq(veloLpRemovalStep.inputToken(_data), LP_TOKEN);
    address[] memory _outputs = veloLpRemovalStep.outputTokens(_data);
    assertEq(_outputs.length, 2);
    assertEq(_outputs[0], TOKEN_A);
    assertEq(_outputs[1], TOKEN_B);
  }

  function test_VeloLPRemoveAndSwap_Metadata() public view {
    bytes memory _data = abi.encode(
      VeloLPRemoveAndSwapStep.Data({
        router: ROUTER,
        factory: FACTORY,
        lpToken: LP_TOKEN,
        tokenA: TOKEN_A,
        tokenB: TOKEN_B,
        stableLp: false,
        stableSwap: true,
        deadlineBuffer: 1 hours
      })
    );
    _assertSingleOutputMetadata(veloLpRemoveAndSwapStep, _data, bytes32('VELO_LP_REMOVE_SWAP'), LP_TOKEN, TOKEN_A);
  }

  function test_VeloSwap_Metadata() public view {
    bytes memory _data = abi.encode(
      VeloSwapStep.Data({
        router: ROUTER,
        factory: FACTORY,
        tokenIn: TOKEN_IN,
        tokenOut: TOKEN_OUT,
        stable: true,
        deadlineBuffer: 1 hours
      })
    );
    _assertSingleOutputMetadata(veloSwapStep, _data, bytes32('VELO_SWAP'), TOKEN_IN, TOKEN_OUT);
  }

  function test_Yearn_Metadata() public view {
    bytes memory _data = abi.encode(
      YearnVaultWithdrawalStep.Data({vault: VAULT, vaultToken: LP_TOKEN, lpToken: TOKEN_OUT, shareScale: 1e18})
    );
    _assertSingleOutputMetadata(yearnStep, _data, bytes32('YEARN_WITHDRAW'), LP_TOKEN, TOKEN_OUT);
  }
}
