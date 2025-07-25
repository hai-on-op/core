// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import {WrappedToken, IWrappedToken} from "@contracts/tokens/WrappedToken.sol";
import {IVotingEscrow} from "@interfaces/external/IVotingEscrow.sol";
import {WrappedTokenV2, IWrappedTokenV2} from "@contracts/tokens/WrappedTokenV2.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IAuthorizable} from "@interfaces/utils/IAuthorizable.sol";
import {HaiTest, stdStorage, StdStorage} from "@test/utils/HaiTest.t.sol";

abstract contract Base is HaiTest {
    using stdStorage for StdStorage;

    address deployer = label("deployer");
    address authorizedAccount = label("authorizedAccount");
    address user = label("user");
    address baseTokenManager = label("baseTokenManager");

    WrappedToken wrappedTokenV1;
    WrappedTokenV2 wrappedTokenV2;

    IERC20 mockBaseToken;
    IVotingEscrow mockBaseTokenNFT;
    string name = "HAI Base Token";
    string symbol = "haiBTKN";

    function setUp() public virtual {
        vm.startPrank(deployer);

        // Deploy mock base token
        mockBaseToken = IERC20(mockContract("BaseToken"));

        // Deploy mock base token NFT
        mockBaseTokenNFT = IVotingEscrow(mockContract("BaseTokenNFT"));

        wrappedTokenV1 = new WrappedToken(
            name,
            symbol,
            address(mockBaseToken),
            baseTokenManager
        );

        wrappedTokenV2 = new WrappedTokenV2(
            name,
            symbol,
            address(mockBaseToken),
            address(mockBaseTokenNFT),
            baseTokenManager,
            address(wrappedTokenV1)
        );

        wrappedTokenV2.addAuthorization(authorizedAccount);

        vm.stopPrank();
    }
}

contract Unit_WrappedToken_Constructor is Base {
    event AddAuthorization(address _account);

    modifier happyPath() {
        vm.startPrank(user);
        _;
    }

    function test_Set_Name(string memory _name) public happyPath {
        wrappedTokenV2 = new WrappedTokenV2(
            _name,
            symbol,
            address(mockBaseToken),
            address(mockBaseTokenNFT),
            baseTokenManager,
            address(wrappedTokenV1)
        );
        assertEq(wrappedTokenV2.name(), _name);
    }

    function test_Set_Symbol(string memory _symbol) public happyPath {
        wrappedTokenV2 = new WrappedTokenV2(
            name,
            _symbol,
            address(mockBaseToken),
            address(mockBaseTokenNFT),
            baseTokenManager,
            address(wrappedTokenV1)
        );
        assertEq(wrappedTokenV2.symbol(), _symbol);
    }

    function test_Set_BaseToken() public happyPath {
        assertEq(address(wrappedTokenV2.BASE_TOKEN()), address(mockBaseToken));
    }

    function test_Set_BaseTokenManager() public happyPath {
        assertEq(wrappedTokenV2.baseTokenManager(), baseTokenManager);
    }

    function test_Revert_NullBaseToken() public happyPath {
        vm.expectRevert(IWrappedTokenV2.WrappedTokenV2_NullBaseToken.selector);
        new WrappedTokenV2(
            name,
            symbol,
            address(0),
            address(mockBaseTokenNFT),
            baseTokenManager,
            address(wrappedTokenV1)
        );
    }

    function test_Revert_NullBaseTokenManager() public happyPath {
        vm.expectRevert(
            IWrappedTokenV2.WrappedTokenV2_NullBaseTokenManager.selector
        );
        new WrappedTokenV2(
            name,
            symbol,
            address(mockBaseToken),
            address(mockBaseTokenNFT),
            address(0),
            address(wrappedTokenV1)
        );
    }

    function test_Emit_AddAuthorization() public happyPath {
        vm.expectEmit();
        emit AddAuthorization(user);
        new WrappedTokenV2(
            name,
            symbol,
            address(mockBaseToken),
            address(mockBaseTokenNFT),
            baseTokenManager,
            address(wrappedTokenV1)
        );
    }
}

contract Unit_WrappedToken_Deposit is Base {
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event WrappedTokenV2Deposit(address indexed _account, uint256 _wad);

    modifier happyPath(address _account, uint256 _wad) {
        vm.startPrank(user);
        _assumeHappyPath(_account, _wad);
        _;
    }

    function _assumeHappyPath(address _account, uint256 _wad) internal pure {
        vm.assume(_account != address(0));
        vm.assume(_wad > 0);
        vm.assume(_wad <= type(uint208).max);
    }

    function test_Revert_NullReceiver(uint256 _wad) public {
        vm.startPrank(user);
        vm.assume(_wad > 0);

        vm.expectRevert(IWrappedTokenV2.WrappedTokenV2_NullReceiver.selector);
        wrappedTokenV2.deposit(address(0), _wad);
    }

    function test_Revert_NullAmount(address _account) public {
        vm.startPrank(user);
        vm.assume(_account != address(0));

        vm.expectRevert(IWrappedTokenV2.WrappedTokenV2_NullAmount.selector);
        wrappedTokenV2.deposit(_account, 0);
    }

    function test_Call_TransferFrom(
        address _account,
        uint256 _wad
    ) public happyPath(_account, _wad) {
        vm.expectCall(
            address(mockBaseToken),
            abi.encodeCall(IERC20.transferFrom, (user, baseTokenManager, _wad))
        );
        wrappedTokenV2.deposit(_account, _wad);
    }

    function test_Mint_Tokens(
        address _account,
        uint256 _wad
    ) public happyPath(_account, _wad) {
        uint256 _balanceBefore = wrappedTokenV2.balanceOf(_account);

        wrappedTokenV2.deposit(_account, _wad);

        assertEq(wrappedTokenV2.balanceOf(_account), _balanceBefore + _wad);
    }

    function test_Emit_Transfer(
        address _account,
        uint256 _wad
    ) public happyPath(_account, _wad) {
        vm.expectEmit();
        emit Transfer(address(0), _account, _wad);

        wrappedTokenV2.deposit(_account, _wad);
    }

    function test_Emit_WrappedTokenDeposit(
        address _account,
        uint256 _wad
    ) public happyPath(_account, _wad) {
        vm.expectEmit();
        emit WrappedTokenV2Deposit(_account, _wad);

        wrappedTokenV2.deposit(_account, _wad);
    }
}

contract Unit_WrappedToken_ModifyParameters is Base {
    modifier happyPath() {
        vm.startPrank(authorizedAccount);
        _;
    }

    function test_ModifyParameters_Set_BaseTokenManager_Contract(
        address _baseTokenManager
    ) public happyPath mockAsContract(_baseTokenManager) {
        wrappedTokenV2.modifyParameters(
            "baseTokenManager",
            abi.encode(_baseTokenManager)
        );

        assertEq(wrappedTokenV2.baseTokenManager(), _baseTokenManager);
    }

    function test_ModifyParameters_Set_BaseTokenManager_EOA(
        address _baseTokenManager
    ) public happyPath {
        vm.assume(_baseTokenManager != address(0));
        wrappedTokenV2.modifyParameters(
            "baseTokenManager",
            abi.encode(_baseTokenManager)
        );

        assertEq(wrappedTokenV2.baseTokenManager(), _baseTokenManager);
    }
}
