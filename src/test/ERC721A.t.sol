// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.0;

import {DSTest} from "ds-test/test.sol";
import {Utilities} from "./utils/Utilities.sol";
import {console} from "./utils/Console.sol";
import {Vm} from "forge-std/Vm.sol";
import {ERC721AMock} from "./mocks/ERC721AMock.sol";

interface ERC721TokenReceiver {
    function onERC721Received(
        address operator,
        address from,
        uint256 id,
        bytes calldata data
    ) external returns (bytes4);
}

contract ERC721Recipient is ERC721TokenReceiver {
    address public operator;
    address public from;
    uint256 public id;
    bytes public data;

    event Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes data,
        uint256 gas
    );

    function onERC721Received(
        address _operator,
        address _from,
        uint256 _id,
        bytes calldata _data
    ) public virtual override returns (bytes4) {
        operator = _operator;
        from = _from;
        id = _id;
        data = _data;

        emit Received(operator, from, id, data, gasleft());

        return ERC721TokenReceiver.onERC721Received.selector;
    }
}

contract ContractTest is DSTest, ERC721Recipient {
    Vm internal immutable vm = Vm(HEVM_ADDRESS);

    ERC721AMock internal nftToken;

    Utilities internal utils;
    address payable[] internal users;

    address internal alice;
    address internal bob;

    event ApprovalForAll(
        address indexed owner,
        address indexed operator,
        bool approved
    );

    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed id
    );

    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 indexed id
    );

    function setUp() public {
        utils = new Utilities();
        users = utils.createUsers(5);
        nftToken = new ERC721AMock("Azuki", "AZUKI");

        alice = users[0];
        bob = users[1];
    }

    function test_EIP165Support() public {
        assertTrue(nftToken.supportsInterface(0x80ac58cd));
        assertTrue(nftToken.supportsInterface(0x5b5e139f));
        assertTrue(!nftToken.supportsInterface(0x780e9d63));
        assertTrue(!nftToken.supportsInterface(0x00000042));
    }

    function test_noMintedTokens() public {
        assertEq(nftToken.totalSupply(), 0);
        assertEq(nftToken.totalMinted(), 0);
    }

    function test_ERC721Metadata() public {
        assertEq(nftToken.name(), "Azuki");
        assertEq(nftToken.symbol(), "AZUKI");
    }

    function test_TokenURIExists() public {
        nftToken.safeMint(address(this), 1);
        assertEq(nftToken.tokenURI(0), "");
    }

    function test_TokenURINotExists() public {
        vm.expectRevert(
            abi.encodeWithSignature("URIQueryForNonexistentToken()")
        );

        nftToken.tokenURI(42);
    }

    function text_exists() public {
        nftToken.safeMint(address(this), 1);
        nftToken.safeMint(address(this), 5);

        for (uint256 index = 0; index < 6; index++) {
            assertTrue(nftToken.exists(index));
        }

        assertTrue(!nftToken.exists(10));
    }

    function test_BalanceOf() public {
        nftToken.safeMint(address(this), 1);
        nftToken.safeMint(alice, 2);
        nftToken.safeMint(bob, 3);

        assertEq(nftToken.balanceOf(address(this)), 1);
        assertEq(nftToken.balanceOf(alice), 2);
        assertEq(nftToken.balanceOf(bob), 3);

        vm.expectRevert(
            abi.encodeWithSignature("BalanceQueryForZeroAddress()")
        );
        nftToken.balanceOf(address(0));
    }

    function test_numberMinted() public {
        nftToken.safeMint(address(this), 1);
        nftToken.safeMint(alice, 2);
        nftToken.safeMint(bob, 3);

        assertEq(nftToken.numberMinted(address(this)), 1);
        assertEq(nftToken.numberMinted(alice), 2);
        assertEq(nftToken.numberMinted(bob), 3);
    }

    function test_totalMinted() public {
        nftToken.safeMint(address(this), 1);
        nftToken.safeMint(alice, 2);
        nftToken.safeMint(bob, 3);

        assertEq(nftToken.totalMinted(), 6);
    }

    function test_aux() public {
        uint64 uint64Max = 18446744073709551615;

        assertEq(nftToken.getAux(address(this)), 0);
        nftToken.setAux(address(this), uint64Max);
        assertEq(nftToken.getAux(address(this)), uint64Max);

        assertEq(nftToken.getAux(alice), 0);
        nftToken.setAux(alice, 1);
        assertEq(nftToken.getAux(alice), 1);

        assertEq(nftToken.getAux(bob), 0);
        nftToken.setAux(bob, 2);
        assertEq(nftToken.getAux(bob), 2);
    }

    function test_ownerOf() public {
        nftToken.safeMint(address(this), 1);
        nftToken.safeMint(alice, 2);
        nftToken.safeMint(bob, 3);

        assertEq(nftToken.ownerOf(0), address(this));
        assertEq(nftToken.ownerOf(1), alice);
        assertEq(nftToken.ownerOf(3), bob);
    }

    function test_ownerOfFailed() public {
        vm.expectRevert(
            abi.encodeWithSignature("OwnerQueryForNonexistentToken()")
        );

        nftToken.ownerOf(42);
    }

    function test_approve() public {
        nftToken.safeMint(address(this), 1);
        nftToken.approve(bob, 0);
        address approval = nftToken.getApproved(0);

        assertEq(approval, bob);
    }

    function test_approveFailedCurrentOwner() public {
        nftToken.safeMint(address(this), 1);
        vm.expectRevert(abi.encodeWithSignature("ApprovalToCurrentOwner()"));
        nftToken.approve(address(this), 0);
    }

    function test_approveFailedUnapprovedCaller() public {
        nftToken.safeMint(address(this), 1);
        nftToken.safeMint(alice, 1);

        vm.expectRevert(
            abi.encodeWithSignature("ApprovalCallerNotOwnerNorApproved()")
        );
        nftToken.approve(bob, 1);
    }

    function test_approveFailedNonExistentToken() public {
        vm.expectRevert(
            abi.encodeWithSignature("ApprovalQueryForNonexistentToken()")
        );
        nftToken.getApproved(111);
    }

    function test_setApprovalForAll() public {
        nftToken.safeMint(address(this), 1);

        vm.expectEmit(true, true, false, true);
        emit ApprovalForAll(address(this), alice, true);

        nftToken.setApprovalForAll(alice, true);

        // We emit the event we expect to see.
        assertTrue(nftToken.isApprovedForAll(address(this), alice));
    }

    function test_setApprovalFailed() public {
        nftToken.safeMint(address(this), 1);

        vm.expectRevert(abi.encodeWithSignature("ApproveToCaller()"));

        nftToken.setApprovalForAll(address(this), true);
    }

    function test_transferToGivenAddress() public {
        nftToken.safeMint(address(this), 1);

        vm.expectEmit(true, true, false, true);
        emit Transfer(address(this), alice, 0);
        nftToken.transferFrom(address(this), alice, 0);

        assertEq(nftToken.ownerOf(0), alice);
        assertEq(nftToken.balanceOf(address(this)), 0);
        assertEq(nftToken.balanceOf(alice), 1);
    }

    function test_clearApprovalAfterTransfer() public {
        nftToken.safeMint(address(this), 1);

        vm.expectEmit(true, true, false, true);
        emit Approval(address(this), address(0), 0);
        nftToken.transferFrom(address(this), alice, 0);

        assertEq(nftToken.getApproved(0), address(0));
    }

    function test_failedUnapprovedTransfer() public {
        nftToken.safeMint(alice, 1);

        vm.expectRevert(
            abi.encodeWithSignature("TransferCallerNotOwnerNorApproved()")
        );
        nftToken.transferFrom(alice, bob, 0);
    }

    function test_failedNonOwnerTransfer() public {
        nftToken.safeMint(alice, 1);

        vm.expectRevert(
            abi.encodeWithSignature("TransferFromIncorrectOwner()")
        );
        nftToken.transferFrom(address(this), bob, 0);
    }

    function test_failedTransferToZeroAddress() public {
        nftToken.safeMint(address(this), 1);

        vm.expectRevert(abi.encodeWithSignature("TransferToZeroAddress()"));
        nftToken.transferFrom(address(this), address(0), 0);
    }
}
