// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {HaiTest} from '@test/utils/HaiTest.t.sol';
import {MainnetDeployment} from '@script/MainnetDeployment.s.sol';
import {StabilityPool} from '@contracts/stability-pool/StabilityPool.sol';
import {EmissionsController} from '@contracts/stability-pool/EmissionsController.sol';
import {IStabilityPool} from '@interfaces/IStabilityPool.sol';
import {IStrategyStep} from '@interfaces/IStrategyStep.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {BalancerV3StablePoolMathSwapStep} from
  '@contracts/stability-pool/strategy-steps/BalancerV3StablePoolMathSwapStep.sol';
import {ERC4626WithdrawalStep} from '@contracts/stability-pool/strategy-steps/ERC4626WithdrawalStep.sol';
import {CurveSwapStep} from '@contracts/stability-pool/strategy-steps/CurveSwapStep.sol';
import {VeloSwapStep} from '@contracts/stability-pool/strategy-steps/VeloSwapStep.sol';
import {VeloCLSwapStepViewQuoter} from '@contracts/stability-pool/strategy-steps/VeloCLSwapStepViewQuoter.sol';
import {VeloLPRemoveAndSwapStep} from '@contracts/stability-pool/strategy-steps/VeloLPRemoveAndSwapStep.sol';
import {BeefyVaultWithdrawalStep} from '@contracts/stability-pool/strategy-steps/BeefyVaultWithdrawalStep.sol';
import {YearnVaultWithdrawalStep} from '@contracts/stability-pool/strategy-steps/YearnVaultWithdrawalStep.sol';

contract E2EStabilityPoolStrategyPipelinesForkTest is HaiTest, MainnetDeployment {
  uint256 internal constant FORK_BLOCK = 148_368_730;
  uint256 internal constant TOTAL_KITE = 1_000_000e18;
  uint256 internal constant DEVIATION_LIMIT = 0.1e18;
  uint256 internal constant EMISSIONS_DURATION = 365 days;

  bytes32 internal constant WETH_CTYPE = bytes32('WETH');
  bytes32 internal constant WSTETH_CTYPE = bytes32('WSTETH');
  bytes32 internal constant ALETH_CTYPE = bytes32('ALETH');
  bytes32 internal constant RETH_CTYPE = bytes32('RETH');
  bytes32 internal constant HAIVELOV2_CTYPE = bytes32('HAIVELOV2');
  bytes32 internal constant TBTC_CTYPE = bytes32('TBTC');
  bytes32 internal constant MSETH_CTYPE = bytes32('MSETH');
  bytes32 internal constant OP_CTYPE = bytes32('OP');
  bytes32 internal constant MOO_VELO_BOLD_LUSD_CTYPE = bytes32('MOO-VELO-BOLD-LUSD');
  bytes32 internal constant YV_VELO_ALETH_WETH_CTYPE = bytes32('YV-VELO-ALETH-WETH');
  bytes32 internal constant YV_VELO_MSETH_WETH_CTYPE = bytes32('YV-VELO-MSETH-WETH');
  bytes32 internal constant HAIAERO_CTYPE = bytes32('HAIAERO');

  // --- contracts ---
  address internal constant VELO_CL_FACTORY = 0xCc0bDDB707055e04e497aB22a59c2aF4391cd12F;
  address internal constant VELO_CL_ROUTER = 0x0792a633F0c19c351081CF4B211F68F79bCc9676;
  address internal constant VELO_ROUTER = 0xa062aE8A9c5e11aaA026fc2670B0D65cCc8B2858;
  address internal constant VELO_FACTORY = 0xF1046053aa5682b4F9a81b5481394DA16BE5FF5a;
  address internal constant BALANCER_V3_ROUTER = 0x84813aA3e079A665C0B80F944427eE83cBA63617;

  // --- tokens ---
  address internal constant WETH_ADDR = 0x4200000000000000000000000000000000000006;
  address internal constant WSTETH_ADDR = 0x1F32b1c2345538c0c6f582fCB022739c4A194Ebb;
  address internal constant USDC_ADDR = 0x0b2C639c533813f4Aa9D7837CAf62653d097Ff85;
  address internal constant BOLD_ADDR = 0x03569CC076654F82679C4BA2124D64774781B01D;
  address internal constant HAI_ADDR = 0x10398AbC267496E49106B07dd6BE13364D10dC71;
  address internal constant ALETH_ADDR = 0x3E29D3A9316dAB217754d13b28646B76607c5f04;
  address internal constant RETH_ADDR = 0x9Bcef72be871e61ED4fBbc7630889beE758eb81D;
  address internal constant WA_OPT_WETH_ADDR = 0x464b808c2C7E04b07e860fDF7a91870620246148;
  address internal constant HAIVELO_ADDR = 0x20A7EaF4a922DF50b312ef61AeA8B6E1deb5DdD6;
  address internal constant VELO_ADDR = 0x9560e827aF36c94D2Ac33a39bCE1Fe78631088Db;
  address internal constant TBTC_ADDR = 0x6c84a8f1c29108F47a79964b5Fe888D4f4D0dE40;
  address internal constant WBTC_ADDR = 0x68f180fcCe6836688e9084f035309E29Bf0A2095;
  address internal constant MSETH_ADDR = 0x1610e3c85dd44Af31eD7f33a63642012Dca0C5A5;
  address internal constant OP_ADDR = 0x4200000000000000000000000000000000000042;
  address internal constant LUSD_ADDR = 0xc40F949F8a4e094D1b49a23ea9241D289B7b2819;

  // --- pools ---
  address internal constant CURVE_BOLD_HAI_POOL = 0xC4ea2ED83bC9207398fa5dB31Ee4E7477dC34fd5;
  address internal constant BALANCER_V3_RETH_WA_OPT_WETH_POOL = 0x870c0Af8A1af0B58b4b0bD31CE4fe72864ae45BE;
  address internal constant BOLD_LUSD_VELO_POOL = 0xf2034BF7922620b721183a894a3449bad7Ee97b3;
  address internal constant ALETH_WETH_VELO_POOL = 0xa1055762336F92b4B8d2eDC032A0Ce45ead6280a;
  address internal constant MSETH_WETH_VELO_POOL = 0x917AA69D539D6518440dd0BEA2eaAc142a8d5610;

  // --- vaults ---
  address internal constant BOLD_LUSD_VELO_BEEFY_VAULT = 0xC06C0A19d0A3eD7B3BA9D7c3101B6BC9634b84a9;
  address internal constant ALETH_WETH_YEARN_VAULT = 0xf7D66b41Cd4241eae450fd9D2d6995754634D9f3;
  address internal constant MSETH_WETH_YEARN_VAULT = 0xd0d2Ac44Cc842079e978bB11b094764f7D0dec6A;

  uint256 internal constant WETH_AMOUNT_IN = 1e16;
  uint256 internal constant WSTETH_AMOUNT_IN = 1e16;
  uint256 internal constant ALETH_AMOUNT_IN = 1e16;
  uint256 internal constant RETH_AMOUNT_IN = 8_633_153_881_674_896;
  uint256 internal constant HAIVELOV2_AMOUNT_IN = 1e18;
  uint256 internal constant TBTC_AMOUNT_IN = 1e15;
  uint256 internal constant MSETH_AMOUNT_IN = 1e16;
  uint256 internal constant OP_AMOUNT_IN = 1e18;
  uint256 internal constant MOO_BOLD_LUSD_AMOUNT_IN = 1e16;
  uint256 internal constant YV_ALETH_WETH_AMOUNT_IN = 1e16;
  uint256 internal constant YV_MSETH_WETH_AMOUNT_IN = 1e16;
  uint256 internal constant HAIAERO_AMOUNT_IN = 1e18;

  address internal testDeployer = label('testDeployer');

  EmissionsController internal emissionsController;
  StabilityPool internal stabilityPool;

  BalancerV3StablePoolMathSwapStep internal balancerV3Step;
  ERC4626WithdrawalStep internal erc4626Step;
  CurveSwapStep internal curveStep;
  VeloSwapStep internal veloStep;
  VeloCLSwapStepViewQuoter internal veloCLStep;
  VeloLPRemoveAndSwapStep internal veloLPRemoveAndSwapStep;
  BeefyVaultWithdrawalStep internal beefyStep;
  YearnVaultWithdrawalStep internal yearnStep;

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('mainnet'), FORK_BLOCK);

    vm.prank(address(timelock));
    try protocolToken.unpause() {} catch {}

    vm.startPrank(testDeployer);
    emissionsController = new EmissionsController(
      IERC20(address(protocolToken)), oracleRelayer, testDeployer, TOTAL_KITE, EMISSIONS_DURATION, DEVIATION_LIMIT
    );

    stabilityPool = new StabilityPool(
      address(systemCoin),
      address(protocolToken),
      address(oracleRelayer),
      address(emissionsController),
      address(coinJoin),
      address(collateralJoinFactory)
    );
    emissionsController.setStabilityRewardsReceiver(address(stabilityPool));

    balancerV3Step = new BalancerV3StablePoolMathSwapStep();
    erc4626Step = new ERC4626WithdrawalStep();
    curveStep = new CurveSwapStep();
    veloStep = new VeloSwapStep();
    veloCLStep = new VeloCLSwapStepViewQuoter();
    veloLPRemoveAndSwapStep = new VeloLPRemoveAndSwapStep();
    beefyStep = new BeefyVaultWithdrawalStep();
    yearnStep = new YearnVaultWithdrawalStep();

    stabilityPool.setStepWhitelist(address(balancerV3Step), true);
    stabilityPool.setStepWhitelist(address(erc4626Step), true);
    stabilityPool.setStepWhitelist(address(curveStep), true);
    stabilityPool.setStepWhitelist(address(veloStep), true);
    stabilityPool.setStepWhitelist(address(veloCLStep), true);
    stabilityPool.setStepWhitelist(address(veloLPRemoveAndSwapStep), true);
    stabilityPool.setStepWhitelist(address(beefyStep), true);
    stabilityPool.setStepWhitelist(address(yearnStep), true);
    vm.stopPrank();
  }

  function test_preview_swap_to_hai_weth_pipeline_matches_chained_step_previews() public {
    _assertPipelineMatches(WETH_CTYPE, WETH_AMOUNT_IN, _wethPipeline());
  }

  function test_preview_swap_to_hai_wsteth_pipeline_matches_chained_step_previews() public {
    _assertPipelineMatches(WSTETH_CTYPE, WSTETH_AMOUNT_IN, _wstethPipeline());
  }

  function test_preview_swap_to_hai_aleth_pipeline_matches_chained_step_previews() public {
    _assertPipelineMatches(ALETH_CTYPE, ALETH_AMOUNT_IN, _alethPipeline());
  }

  function test_preview_swap_to_hai_reth_pipeline_matches_chained_step_previews() public {
    _assertPipelineMatches(RETH_CTYPE, RETH_AMOUNT_IN, _rethPipeline());
  }

  function test_preview_swap_to_hai_haivelov2_pipeline_matches_chained_step_previews() public {
    _assertPipelineMatches(HAIVELOV2_CTYPE, HAIVELOV2_AMOUNT_IN, _haiveloV2Pipeline());
  }

  function test_preview_swap_to_hai_tbtc_pipeline_matches_chained_step_previews() public {
    _assertPipelineMatches(TBTC_CTYPE, TBTC_AMOUNT_IN, _tbtcPipeline());
  }

  function test_preview_swap_to_hai_mseth_pipeline_matches_chained_step_previews() public {
    _assertPipelineMatches(MSETH_CTYPE, MSETH_AMOUNT_IN, _msethPipeline());
  }

  function test_preview_swap_to_hai_op_pipeline_matches_chained_step_previews() public {
    _assertPipelineMatches(OP_CTYPE, OP_AMOUNT_IN, _opPipeline());
  }

  function test_preview_swap_to_hai_mooveloboldlusd_pipeline_matches_chained_step_previews() public {
    _assertPipelineMatches(MOO_VELO_BOLD_LUSD_CTYPE, MOO_BOLD_LUSD_AMOUNT_IN, _mooVeloBoldLusdPipeline());
  }

  function test_preview_swap_to_hai_yvveloalethweth_pipeline_matches_chained_step_previews() public {
    _assertPipelineMatches(YV_VELO_ALETH_WETH_CTYPE, YV_ALETH_WETH_AMOUNT_IN, _yvVeloAlethWethPipeline());
  }

  function test_preview_swap_to_hai_yvvelomsethweth_pipeline_matches_chained_step_previews() public {
    _assertPipelineMatches(YV_VELO_MSETH_WETH_CTYPE, YV_MSETH_WETH_AMOUNT_IN, _yvVeloMsethWethPipeline());
  }

  function test_preview_swap_to_hai_haiaero_pipeline_no_steps_configured() public {
    vm.expectRevert(IStabilityPool.StabilityPool_NoStrategySteps.selector);
    stabilityPool.previewSwapToHai(HAIAERO_CTYPE, HAIAERO_AMOUNT_IN);
  }

  function _assertPipelineMatches(
    bytes32 _cType,
    uint256 _amountIn,
    IStabilityPool.StepConfig[] memory _steps
  ) internal {
    assertTrue(stabilityPool.collateralJoinFactory().collateralJoins(_cType) != address(0), 'collateral join not found');
    _setStrategySteps(_cType, _steps);

    uint256 _manualExpected = _previewChained(_steps, _amountIn);
    uint256 _poolPreview = stabilityPool.previewSwapToHai(_cType, _amountIn);

    assertEq(_poolPreview, _manualExpected, 'preview mismatch');
    assertGt(_poolPreview, 0, 'expected HAI preview should be > 0');
  }

  function _previewChained(
    IStabilityPool.StepConfig[] memory _steps,
    uint256 _amountIn
  ) internal view returns (uint256 _finalOut) {
    _finalOut = _amountIn;

    for (uint256 _i; _i < _steps.length; _i++) {
      uint256[] memory _outs = IStrategyStep(_steps[_i].step).preview(_steps[_i].data, _finalOut);
      require(_outs.length == 1, 'unexpected outputs length');
      require(_outs[0] > 0, 'step preview output should be > 0');
      _finalOut = _outs[0];
    }
  }

  function _setStrategySteps(bytes32 _cType, IStabilityPool.StepConfig[] memory _steps) internal {
    vm.prank(testDeployer);
    stabilityPool.setStrategySteps(_cType, _steps);
    assertEq(stabilityPool.strategyStepsLength(_cType), _steps.length);
  }

  function _cfg(address _step, bytes memory _data) internal pure returns (IStabilityPool.StepConfig memory _config) {
    _config = IStabilityPool.StepConfig({step: _step, data: _data, slippageBps: 0});
  }

  function _wethPipeline() internal view returns (IStabilityPool.StepConfig[] memory _steps) {
    _steps = new IStabilityPool.StepConfig[](3);
    _steps[0] = _cfg(address(veloCLStep), _wethToUsdcVeloClData());
    _steps[1] = _cfg(address(veloStep), _usdcToBoldVeloData());
    _steps[2] = _cfg(address(curveStep), _boldToHaiCurveData());
  }

  function _wstethPipeline() internal view returns (IStabilityPool.StepConfig[] memory _steps) {
    _steps = new IStabilityPool.StepConfig[](4);
    _steps[0] = _cfg(address(veloCLStep), _wstethToWethVeloClData());
    _steps[1] = _cfg(address(veloCLStep), _wethToUsdcVeloClData());
    _steps[2] = _cfg(address(veloStep), _usdcToBoldVeloData());
    _steps[3] = _cfg(address(curveStep), _boldToHaiCurveData());
  }

  function _alethPipeline() internal view returns (IStabilityPool.StepConfig[] memory _steps) {
    _steps = new IStabilityPool.StepConfig[](4);
    _steps[0] = _cfg(address(veloStep), _alethToWethVeloData());
    _steps[1] = _cfg(address(veloCLStep), _wethToUsdcVeloClData());
    _steps[2] = _cfg(address(veloStep), _usdcToBoldVeloData());
    _steps[3] = _cfg(address(curveStep), _boldToHaiCurveData());
  }

  function _rethPipeline() internal view returns (IStabilityPool.StepConfig[] memory _steps) {
    _steps = new IStabilityPool.StepConfig[](5);
    _steps[0] = _cfg(address(balancerV3Step), _rethToWaOptWethBalancerV3Data());
    _steps[1] = _cfg(address(erc4626Step), _waOptWethToWethErc4626Data());
    _steps[2] = _cfg(address(veloCLStep), _wethToUsdcVeloClData());
    _steps[3] = _cfg(address(veloStep), _usdcToBoldVeloData());
    _steps[4] = _cfg(address(curveStep), _boldToHaiCurveData());
  }

  function _haiveloV2Pipeline() internal view returns (IStabilityPool.StepConfig[] memory _steps) {
    _steps = new IStabilityPool.StepConfig[](4);
    _steps[0] = _cfg(address(veloStep), _haiveloToVeloVeloData());
    _steps[1] = _cfg(address(veloStep), _veloToUsdcVeloData());
    _steps[2] = _cfg(address(veloStep), _usdcToBoldVeloData());
    _steps[3] = _cfg(address(curveStep), _boldToHaiCurveData());
  }

  function _tbtcPipeline() internal view returns (IStabilityPool.StepConfig[] memory _steps) {
    _steps = new IStabilityPool.StepConfig[](4);
    _steps[0] = _cfg(address(veloCLStep), _tbtcToWbtcVeloClData());
    _steps[1] = _cfg(address(veloCLStep), _wbtcToUsdcVeloClData());
    _steps[2] = _cfg(address(veloStep), _usdcToBoldVeloData());
    _steps[3] = _cfg(address(curveStep), _boldToHaiCurveData());
  }

  function _msethPipeline() internal view returns (IStabilityPool.StepConfig[] memory _steps) {
    _steps = new IStabilityPool.StepConfig[](4);
    _steps[0] = _cfg(address(veloStep), _msethToWethVeloData());
    _steps[1] = _cfg(address(veloCLStep), _wethToUsdcVeloClData());
    _steps[2] = _cfg(address(veloStep), _usdcToBoldVeloData());
    _steps[3] = _cfg(address(curveStep), _boldToHaiCurveData());
  }

  function _opPipeline() internal view returns (IStabilityPool.StepConfig[] memory _steps) {
    _steps = new IStabilityPool.StepConfig[](4);
    _steps[0] = _cfg(address(veloCLStep), _opToWethVeloClData());
    _steps[1] = _cfg(address(veloCLStep), _wethToUsdcVeloClData());
    _steps[2] = _cfg(address(veloStep), _usdcToBoldVeloData());
    _steps[3] = _cfg(address(curveStep), _boldToHaiCurveData());
  }

  function _mooVeloBoldLusdPipeline() internal view returns (IStabilityPool.StepConfig[] memory _steps) {
    _steps = new IStabilityPool.StepConfig[](3);
    _steps[0] = _cfg(address(beefyStep), _beefyBoldLusdWithdrawalData());
    _steps[1] = _cfg(address(veloLPRemoveAndSwapStep), _boldLusdLpRemoveAndSwapData());
    _steps[2] = _cfg(address(curveStep), _boldToHaiCurveData());
  }

  function _yvVeloAlethWethPipeline() internal view returns (IStabilityPool.StepConfig[] memory _steps) {
    _steps = new IStabilityPool.StepConfig[](5);
    _steps[0] = _cfg(address(yearnStep), _yearnAlethWethWithdrawalData());
    _steps[1] = _cfg(address(veloLPRemoveAndSwapStep), _alethWethLpRemoveAndSwapData());
    _steps[2] = _cfg(address(veloCLStep), _wethToUsdcVeloClData());
    _steps[3] = _cfg(address(veloStep), _usdcToBoldVeloData());
    _steps[4] = _cfg(address(curveStep), _boldToHaiCurveData());
  }

  function _yvVeloMsethWethPipeline() internal view returns (IStabilityPool.StepConfig[] memory _steps) {
    _steps = new IStabilityPool.StepConfig[](5);
    _steps[0] = _cfg(address(yearnStep), _yearnMsethWethWithdrawalData());
    _steps[1] = _cfg(address(veloLPRemoveAndSwapStep), _msethWethLpRemoveAndSwapData());
    _steps[2] = _cfg(address(veloCLStep), _wethToUsdcVeloClData());
    _steps[3] = _cfg(address(veloStep), _usdcToBoldVeloData());
    _steps[4] = _cfg(address(curveStep), _boldToHaiCurveData());
  }

  function _wethToUsdcVeloClData() internal pure returns (bytes memory _data) {
    _data = abi.encode(
      VeloCLSwapStepViewQuoter.Data({
        router: VELO_CL_ROUTER,
        pool: 0x478946BcD4a5a22b316470F5486fAfb928C0bA25,
        tokenIn: WETH_ADDR,
        tokenOut: USDC_ADDR,
        tickSpacing: 100,
        sqrtPriceLimitX96: 0,
        deadlineBuffer: 1 hours
      })
    );
  }

  function _wstethToWethVeloClData() internal pure returns (bytes memory _data) {
    _data = abi.encode(
      VeloCLSwapStepViewQuoter.Data({
        router: VELO_CL_ROUTER,
        pool: 0xbF30Ff33CF9C6b0c48702Ff17891293b002DfeA4,
        tokenIn: WSTETH_ADDR,
        tokenOut: WETH_ADDR,
        tickSpacing: 1,
        sqrtPriceLimitX96: 0,
        deadlineBuffer: 1 hours
      })
    );
  }

  function _tbtcToWbtcVeloClData() internal pure returns (bytes memory _data) {
    _data = abi.encode(
      VeloCLSwapStepViewQuoter.Data({
        router: VELO_CL_ROUTER,
        pool: 0x8949A8E02998d76D7a703cAC9eE7e0f529828011,
        tokenIn: TBTC_ADDR,
        tokenOut: WBTC_ADDR,
        tickSpacing: 1,
        sqrtPriceLimitX96: 0,
        deadlineBuffer: 1 hours
      })
    );
  }

  function _wbtcToUsdcVeloClData() internal pure returns (bytes memory _data) {
    _data = abi.encode(
      VeloCLSwapStepViewQuoter.Data({
        router: VELO_CL_ROUTER,
        pool: 0xCF50DEA65EE80eBDDAA61005a960ef5A5c995A99,
        tokenIn: WBTC_ADDR,
        tokenOut: USDC_ADDR,
        tickSpacing: 100,
        sqrtPriceLimitX96: 0,
        deadlineBuffer: 1 hours
      })
    );
  }

  function _opToWethVeloClData() internal pure returns (bytes memory _data) {
    _data = abi.encode(
      VeloCLSwapStepViewQuoter.Data({
        router: VELO_CL_ROUTER,
        pool: 0x4DC22588Ade05C40338a9D95A6da9dCeE68Bcd60,
        tokenIn: OP_ADDR,
        tokenOut: WETH_ADDR,
        tickSpacing: 200,
        sqrtPriceLimitX96: 0,
        deadlineBuffer: 1 hours
      })
    );
  }

  function _usdcToBoldVeloData() internal pure returns (bytes memory _data) {
    _data = abi.encode(
      VeloSwapStep.Data({
        router: VELO_ROUTER,
        factory: VELO_FACTORY,
        tokenIn: USDC_ADDR,
        tokenOut: BOLD_ADDR,
        stable: true,
        deadlineBuffer: 1 hours
      })
    );
  }

  function _alethToWethVeloData() internal pure returns (bytes memory _data) {
    _data = abi.encode(
      VeloSwapStep.Data({
        router: VELO_ROUTER,
        factory: VELO_FACTORY,
        tokenIn: ALETH_ADDR,
        tokenOut: WETH_ADDR,
        stable: true,
        deadlineBuffer: 1 hours
      })
    );
  }

  function _haiveloToVeloVeloData() internal pure returns (bytes memory _data) {
    _data = abi.encode(
      VeloSwapStep.Data({
        router: VELO_ROUTER,
        factory: VELO_FACTORY,
        tokenIn: HAIVELO_ADDR,
        tokenOut: VELO_ADDR,
        stable: true,
        deadlineBuffer: 1 hours
      })
    );
  }

  function _veloToUsdcVeloData() internal pure returns (bytes memory _data) {
    _data = abi.encode(
      VeloSwapStep.Data({
        router: VELO_ROUTER,
        factory: VELO_FACTORY,
        tokenIn: VELO_ADDR,
        tokenOut: USDC_ADDR,
        stable: false,
        deadlineBuffer: 1 hours
      })
    );
  }

  function _msethToWethVeloData() internal pure returns (bytes memory _data) {
    _data = abi.encode(
      VeloSwapStep.Data({
        router: VELO_ROUTER,
        factory: VELO_FACTORY,
        tokenIn: MSETH_ADDR,
        tokenOut: WETH_ADDR,
        stable: true,
        deadlineBuffer: 1 hours
      })
    );
  }

  function _boldToHaiCurveData() internal pure returns (bytes memory _data) {
    _data = abi.encode(
      CurveSwapStep.Data({pool: CURVE_BOLD_HAI_POOL, i: int128(1), j: int128(0), tokenIn: BOLD_ADDR, tokenOut: HAI_ADDR})
    );
  }

  function _rethToWaOptWethBalancerV3Data() internal pure returns (bytes memory _data) {
    _data = abi.encode(
      BalancerV3StablePoolMathSwapStep.Data({
        router: BALANCER_V3_ROUTER,
        pool: BALANCER_V3_RETH_WA_OPT_WETH_POOL,
        tokenIn: RETH_ADDR,
        tokenOut: WA_OPT_WETH_ADDR,
        deadlineBuffer: 1 hours,
        userData: bytes('')
      })
    );
  }

  function _waOptWethToWethErc4626Data() internal pure returns (bytes memory _data) {
    _data = abi.encode(
      ERC4626WithdrawalStep.Data({vault: WA_OPT_WETH_ADDR, vaultToken: WA_OPT_WETH_ADDR, assetToken: WETH_ADDR})
    );
  }

  function _beefyBoldLusdWithdrawalData() internal pure returns (bytes memory _data) {
    _data = abi.encode(
      BeefyVaultWithdrawalStep.Data({
        vault: BOLD_LUSD_VELO_BEEFY_VAULT,
        vaultToken: BOLD_LUSD_VELO_BEEFY_VAULT,
        lpToken: BOLD_LUSD_VELO_POOL,
        shareScale: 1e18
      })
    );
  }

  function _yearnAlethWethWithdrawalData() internal pure returns (bytes memory _data) {
    _data = abi.encode(
      YearnVaultWithdrawalStep.Data({
        vault: ALETH_WETH_YEARN_VAULT,
        vaultToken: ALETH_WETH_YEARN_VAULT,
        lpToken: ALETH_WETH_VELO_POOL,
        shareScale: 1e18
      })
    );
  }

  function _yearnMsethWethWithdrawalData() internal pure returns (bytes memory _data) {
    _data = abi.encode(
      YearnVaultWithdrawalStep.Data({
        vault: MSETH_WETH_YEARN_VAULT,
        vaultToken: MSETH_WETH_YEARN_VAULT,
        lpToken: MSETH_WETH_VELO_POOL,
        shareScale: 1e18
      })
    );
  }

  function _boldLusdLpRemoveAndSwapData() internal pure returns (bytes memory _data) {
    _data = abi.encode(
      VeloLPRemoveAndSwapStep.Data({
        router: VELO_ROUTER,
        factory: VELO_FACTORY,
        lpToken: BOLD_LUSD_VELO_POOL,
        tokenA: BOLD_ADDR,
        tokenB: LUSD_ADDR,
        stableLp: true,
        stableSwap: true,
        deadlineBuffer: 1 hours
      })
    );
  }

  function _alethWethLpRemoveAndSwapData() internal pure returns (bytes memory _data) {
    _data = abi.encode(
      VeloLPRemoveAndSwapStep.Data({
        router: VELO_ROUTER,
        factory: VELO_FACTORY,
        lpToken: ALETH_WETH_VELO_POOL,
        tokenA: WETH_ADDR,
        tokenB: ALETH_ADDR,
        stableLp: true,
        stableSwap: true,
        deadlineBuffer: 1 hours
      })
    );
  }

  function _msethWethLpRemoveAndSwapData() internal pure returns (bytes memory _data) {
    _data = abi.encode(
      VeloLPRemoveAndSwapStep.Data({
        router: VELO_ROUTER,
        factory: VELO_FACTORY,
        lpToken: MSETH_WETH_VELO_POOL,
        tokenA: WETH_ADDR,
        tokenB: MSETH_ADDR,
        stableLp: true,
        stableSwap: true,
        deadlineBuffer: 1 hours
      })
    );
  }
}
