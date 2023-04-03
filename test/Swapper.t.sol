// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <0.9.0;

import { PRBTest } from "@prb/test/PRBTest.sol";
import { console2 } from "forge-std/console2.sol";
import { StdCheats } from "forge-std/StdCheats.sol";
import "../src/Swapper.sol";

import { ERC20 } from "openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IUniswapV2Router02 } from "v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

/// @dev See the "Writing Tests" section in the Foundry Book if this is your first time with Forge.
/// https://book.getfoundry.sh/forge/writing-tests
contract SwapperTest is PRBTest, StdCheats {
    Swapper sw;

    address SPOOKY_WFTM_USDC_LP = 0x2b4C76d0dc16BE1C31D4C1DC53bF9B45987Fc75c;
    address SPOOKY_USDT_WFTM_LP = 0x5965E53aa80a0bcF1CD6dbDd72e6A9b2AA047410;
    address SPIRIT_WFTM_USDC_LP = 0xe7E90f5a767406efF87Fdad7EB07ef407922EC1D;
    address SOLIDLY_WFTM_USDC_LP = 0xBad7D3DF8E1614d985C3D9ba9f6ecd32ae7Dc20a;
    address CURVE_MIM_USDT_USDC_LP = 0xA58F16498c288c357e28EE899873fF2b55D7C437;

    address SPOOKY_WFTM_BOO_LP = 0xEc7178F4C41f346b2721907F5cF7628E388A7a58;
    address SPIRITV2_WFTM_USDC_LP = 0x772bC1196C357F6E9c80e1cc342e29B3a5F05ef3;

    address WFTM = 0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83;
    address USDC = 0x04068DA6C83AFCFA0e13ba15A6696662335D5B75;
    address USDT = 0x049d68029688eAbF473097a2fC38ef61633A3C7A;
    address BOO = 0x841FAD6EAe12c286d1Fd18d1d525DFfA75C7EFFE;
    address SOUL = 0xe2fb177009FF39F52C0134E8007FA0e4BaAcBd07;

    address BOO_WHALE = 0xa48d959AE2E88f1dAA7D5F611E01908106dE7598;
    address USDC_WHALE = 0x12edeA9cd262006cC3C4E77c90d2CD2DD4b1eb97;
    address WFTM_WHALE = 0x39B3bd37208CBaDE74D0fcBDBb12D606295b430a;

    uint16 SPOOKY_FEE = 9980;
    uint16 SPIRIT_FEE = 9970;
    uint16 SOLIDLY_FEE = 9999;
    uint16 SPIRITV2_FEE = 9982;

    IUniswapV2Router02 booRouter = IUniswapV2Router02(0xF491e7B69E4244ad4002BC14e878a34207E38c29);
    IUniswapV2Router02 spiritRouter = IUniswapV2Router02(0x16327E3FbDaCA3bcF7E38F5Af2599D2DDc33aE52);
    IUniswapV2Router02 ssRouter = IUniswapV2Router02(0x6b3d631B87FE27aF29efeC61d2ab8CE4d621cCBF);
    MummyVault mmVault = MummyVault(0xA6D7D0e650aa40FFa42d845A354c12c2bc0aB15f);

    address[] path;
    address[] path2;

    uint112 amountIn;
    bytes data;
    bytes data2;
    ERC20 wftm = ERC20(WFTM);
    ERC20 usdc = ERC20(USDC);
    ERC20 soul = ERC20(SOUL);

    function setUp() public virtual {
        amountIn = 7114926656500000000000;
        sw = new Swapper();
        transferToken(WFTM_WHALE, address(sw), WFTM, 500_000 * 1e18);

        console2.log("WFTM", wftm.balanceOf(address(this)));
        console2.log("USDC", usdc.balanceOf(address(this)));

        transferToken(WFTM_WHALE, address(mmVault), WFTM, amountIn);
        mmVault.swap(WFTM,USDC,address(this));

        console2.log("WFTM", wftm.balanceOf(address(this)));
        console2.log("USDC", usdc.balanceOf(address(this)));

       
    }

    function transferToken(address from, address to, address token, uint256 transferAmount) public returns (bool) {
        vm.prank(from);
        return IERC20(token).transfer(to, transferAmount);
    }

    function testUniswap() external {
        console2.log("WFTM", wftm.balanceOf(address(sw)));
        console2.log("USDC", usdc.balanceOf(address(sw)));
        uint256 amountOut = sw._getAmountOutUniswapRO(amountIn, SPOOKY_FEE, SPOOKY_WFTM_USDC_LP, WFTM, USDC);
        sw.transfer(WFTM, amountIn, SPOOKY_WFTM_USDC_LP);
        sw._uniswap(amountOut, SPOOKY_WFTM_USDC_LP, WFTM, USDC, address(sw));
        console2.log("WFTM", wftm.balanceOf(address(sw)));
        console2.log("USDC", usdc.balanceOf(address(sw)));
    }
}
