// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.19 <0.9.0;

import { console2 } from "forge-std/console2.sol";
import { StdCheats } from "forge-std/StdCheats.sol";
import "forge-std/Test.sol";
import "../src/Swapper.sol";

import { ERC20 } from "openzeppelin/contracts/token/ERC20/ERC20.sol";
import { IUniswapV2Router02 } from "v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

/// @dev See the "Writing Tests" section in the Foundry Book if this is your first time with Forge.
/// https://book.getfoundry.sh/forge/writing-tests
contract SwapperTest is StdCheats, Test {
    using stdStorage for StdStorage;

    Swapper sw;

    address SPOOKY_WFTM_USDC_LP = 0x2b4C76d0dc16BE1C31D4C1DC53bF9B45987Fc75c;
    address EQUALIZER_WFTM_USDC_LP = 0x7547d05dFf1DA6B4A2eBB3f0833aFE3C62ABD9a1;
    address EQUALIZER_USDC_USDT_LP = 0x0995F3932B4Aca1ED18eE08D4B0DCf5f74B3c5D3;

    address SPOOKY_USDT_WFTM_LP = 0x5965E53aa80a0bcF1CD6dbDd72e6A9b2AA047410;
    address SPIRIT_WFTM_USDC_LP = 0xe7E90f5a767406efF87Fdad7EB07ef407922EC1D;
    address SOLIDLY_WFTM_USDC_LP = 0xBad7D3DF8E1614d985C3D9ba9f6ecd32ae7Dc20a;
    address SPOOKY_USDC_BOO = 0xf8Cb2980120469d79958151daa45Eb937c6E1eD6;

    address CURVE_MIM_USDT_USDC_LP = 0xA58F16498c288c357e28EE899873fF2b55D7C437;
    int128 CURVE_MIM_USDT_USDC_LP_USDT = 1;
    int128 CURVE_MIM_USDT_USDC_LP_USDC = 2;

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

    address BEETHOVEN = 0x20dd72Ed959b6147912C2e529F0a0C651c33c9ce;
    bytes32 BEETHOVEN_WFTM_USDC = 0x56ad84b777ff732de69e85813daee1393a9ffe1000020000000000000000060e;

    uint16 SPOOKY_FEE = 9980;
    uint16 SPIRIT_FEE = 9970;
    uint16 SOLIDLY_FEE = 9999;
    uint16 SPIRITV2_FEE = 9982;

    IUniswapV2Router02 booRouter = IUniswapV2Router02(0xF491e7B69E4244ad4002BC14e878a34207E38c29);
    IUniswapV2Router02 spiritRouter = IUniswapV2Router02(0x16327E3FbDaCA3bcF7E38F5Af2599D2DDc33aE52);
    IUniswapV2Router02 ssRouter = IUniswapV2Router02(0x6b3d631B87FE27aF29efeC61d2ab8CE4d621cCBF);
    GMXVault mmVault = GMXVault(0xA6D7D0e650aa40FFa42d845A354c12c2bc0aB15f);
    address gmAdd = 0xA6D7D0e650aa40FFa42d845A354c12c2bc0aB15f;
    address[] path;
    address[] path2;

    uint256 amountIn;
    bytes data;
    bytes data2;
    ERC20 wftm = ERC20(WFTM);
    ERC20 usdc = ERC20(USDC);
    ERC20 usdt = ERC20(USDT);
    ERC20 soul = ERC20(SOUL);
    ERC20 boo = ERC20(BOO);
    bytes swapDataGSCU =
        hex"0403020401000000000000000000000000000000000000000000000181b3714196f836880000000000000000000000000000000000000000000000006511AA68D77CBAC824A6D7D0e650aa40FFa42d845A354c12c2bc0aB15f21be370D5312f44cB42ce377BC9b8a0cEF1A4C8304068DA6C83AFCFA0e13ba15A6696662335D5B750995F3932B4Aca1ED18eE08D4B0DCf5f74B3c5D304068DA6C83AFCFA0e13ba15A6696662335D5B75049d68029688eAbF473097a2fC38ef61633A3C7AA58F16498c288c357e28EE899873fF2b55D7C4370102f8Cb2980120469d79958151daa45Eb937c6E1eD604068DA6C83AFCFA0e13ba15A6696662335D5B75841FAD6EAe12c286d1Fd18d1d525DFfA75C7EFFE26fc";
    bytes swapDataGSC =
        hex"03030204000000000000000000000000000000000000000000000181b3714196f836880000000000000000000000000000000000000000000000000000000000B9D67F28A6D7D0e650aa40FFa42d845A354c12c2bc0aB15f21be370D5312f44cB42ce377BC9b8a0cEF1A4C8304068DA6C83AFCFA0e13ba15A6696662335D5B750995F3932B4Aca1ED18eE08D4B0DCf5f74B3c5D304068DA6C83AFCFA0e13ba15A6696662335D5B75049d68029688eAbF473097a2fC38ef61633A3C7AA58F16498c288c357e28EE899873fF2b55D7C4370102";
    bytes swapDataGS =
        hex"020302000000000000000000000000000000000000000000000181b3714196f836880000000000000000000000000000000000000000000000000000000000B9C83F02A6D7D0e650aa40FFa42d845A354c12c2bc0aB15f21be370D5312f44cB42ce377BC9b8a0cEF1A4C8304068DA6C83AFCFA0e13ba15A6696662335D5B750995F3932B4Aca1ED18eE08D4B0DCf5f74B3c5D304068DA6C83AFCFA0e13ba15A6696662335D5B75049d68029688eAbF473097a2fC38ef61633A3C7A";
    bytes swapDataG =
        hex"0103000000000000000000000000000000000000000000000181b3714196f836880000000000000000000000000000000000000000000000000000000000BA066CE3A6D7D0e650aa40FFa42d845A354c12c2bc0aB15f21be370D5312f44cB42ce377BC9b8a0cEF1A4C8304068DA6C83AFCFA0e13ba15A6696662335D5B75";
    bytes swapDataB =
        hex"0105000000000000000000000000000000000000000000000181b3714196f836880000000000000000000000000000000000000000000000000000000000B8AE697920dd72Ed959b6147912C2e529F0a0C651c33c9ce56ad84b777ff732de69e85813daee1393a9ffe1000020000000000000000060e21be370D5312f44cB42ce377BC9b8a0cEF1A4C8304068DA6C83AFCFA0e13ba15A6696662335D5B75";
    address swAddress;

    function setUp() public virtual {
        amountIn = 7_114_926_656_500_000_000_000;
        sw = new Swapper();
        swAddress = address(sw);
        writeTokenBalance(address(sw), WFTM, 100_000 * 1e18);
        writeTokenBalance(address(sw), USDC, 100_000 * 1e6);
        writeTokenBalance(address(sw), USDT, 100_000 * 1e6);
        writeTokenBalance(address(sw), BOO, 100_000 * 1e18);

        sw.approve(USDC, CURVE_MIM_USDT_USDC_LP);
        sw.approve(USDT, CURVE_MIM_USDT_USDC_LP);
        sw.approve(WFTM, BEETHOVEN);

        // console2.log("WFTM", wftm.balanceOf(address(this)));
        // console2.log("USDC", usdc.balanceOf(address(this)));

        // transferToken(WFTM_WHALE, address(mmVault), WFTM, amountIn);
        // mmVault.swap(WFTM,USDC,address(this));

        // console2.log("WFTM", wftm.balanceOf(address(this)));
        // console2.log("USDC", usdc.balanceOf(address(this)));
    }

    function writeTokenBalance(address who, address token, uint256 amt) internal {
        stdstore.target(token).sig(IERC20(token).balanceOf.selector).with_key(who).checked_write(amt);
    }

    function transferToken(address from, address to, address token, uint256 transferAmount) public returns (bool) {
        vm.prank(from);
        bool result = IERC20(token).transfer(to, transferAmount);
        console2.log("Ending Balance: ", IERC20(token).balanceOf(from));
        return result;
    }

    // function testSwapManual() external {
    //     writeTokenBalance(address(sw), WFTM, 100_000 * 1e18);
    //     console2.log("WFTM", wftm.balanceOf(address(sw)));
    //     console2.log("USDC", usdc.balanceOf(address(sw)));
    //     console2.log("USDT", usdt.balanceOf(address(sw)));
    //     console2.log("BOO", boo.balanceOf(address(sw)));

    //     sw.transfer(WFTM, amountIn, address(mmVault));
    //     console2.log("CONTRACT->GMX WFTM:", amountIn);
    //     amountIn = sw._gmxswap(address(mmVault), WFTM, USDC, EQUALIZER_USDC_USDT_LP);
    //     console2.log("GMX->EQUALIZER USDC:", amountIn);
    //     amountIn = sw._solidlyswap(amountIn, EQUALIZER_USDC_USDT_LP, USDC, USDT, address(sw));
    //     console2.log("EQUALIZER->CONTRACT USDT:", amountIn);
    //     amountIn =
    //         sw._curveswap(amountIn, CURVE_MIM_USDT_USDC_LP, CURVE_MIM_USDT_USDC_LP_USDT,
    // CURVE_MIM_USDT_USDC_LP_USDC);
    //     console2.log("CONTRACT->CRV->CONTRACT USDC:", amountIn);
    //     sw.transfer(USDC, amountIn, address(SPOOKY_USDC_BOO));
    //     amountIn = sw._uniswap(amountIn, SPOOKY_USDC_BOO, USDC, BOO, address(sw), SPOOKY_FEE);
    //     console2.log("SPOOKY->CONTRACT BOO:", amountIn);

    //     console2.log("WFTM", wftm.balanceOf(address(sw)));
    //     console2.log("USDC", usdc.balanceOf(address(sw)));
    //     console2.log("USDT", usdt.balanceOf(address(sw)));
    //     console2.log("BOO", boo.balanceOf(address(sw)));
    //     // amountOut = sw._solidlyswap(amountOut,EQUALIZER_USDC_USDT_LP,USDC,USDT,address(this));
    //     // sw._curveswap(1000000000,CURVE_MIM_USDT_USDC_LP,CURVE_MIM_USDT_USDC_LP_USDC,CURVE_MIM_USDT_USDC_LP_USDT);

    //     console2.log("WFTM", wftm.balanceOf(address(sw)));
    //     console2.log("USDC", usdc.balanceOf(address(sw)));
    //     console2.log("USDT", usdt.balanceOf(address(sw)));
    //     console2.log("BOO", boo.balanceOf(address(sw)));
    // }

    // SWAPDATA
    // routeLength,routeIdentifier...,amountIn, minAmountOut, routeData...
    // 04
    // 03 60 GMX
    // 02 60 SOLIDLY
    // 04 CURVE
    // 01 UNISWAP
    // 000000000000000000000000000000000000000000000181b3714196f8368800
    // 00000000000000000000000000000000000000000000000000000000b9c83f02
    // A6D7D0e650aa40FFa42d845A354c12c2bc0aB15f||21be370D5312f44cB42ce377BC9b8a0cEF1A4C83||04068DA6C83AFCFA0e13ba15A6696662335D5B75       WFTM->USDC
    // 0995F3932B4Aca1ED18eE08D4B0DCf5f74B3c5D3||04068DA6C83AFCFA0e13ba15A6696662335D5B75||049d68029688eAbF473097a2fC38ef61633A3C7A       USDC->USDT
    // A58F16498c288c357e28EE899873fF2b55D7C437||01||02                                                                                   USDT->USDC
    // f8Cb2980120469d79958151daa45Eb937c6E1eD6||04068DA6C83AFCFA0e13ba15A6696662335D5B75||841FAD6EAe12c286d1Fd18d1d525DFfA75C7EFFE||26fc||USDC->BOO
    function testSwapGSCU() external {
        sw.swap(swapDataGSCU);
        // console2.log("WFTM", wftm.balanceOf(address(sw)));
        // console2.log("USDC", usdc.balanceOf(address(sw)));
        // console2.log("USDT", usdt.balanceOf(address(sw)));
        // console2.log("BOO", boo.balanceOf(address(sw)));
    }

    function testSwapGSC() external {
        sw.swap(swapDataGSC);
        // console2.log("WFTM", wftm.balanceOf(address(sw)));
        // console2.log("USDC", usdc.balanceOf(address(sw)));
        // console2.log("USDT", usdt.balanceOf(address(sw)));
        // console2.log("BOO", boo.balanceOf(address(sw)));
    }

    function testSwapGS() external {
        sw.swap(swapDataGS);
        // console2.log("WFTM", wftm.balanceOf(address(sw)));
        // console2.log("USDC", usdc.balanceOf(address(sw)));
        // console2.log("USDT", usdt.balanceOf(address(sw)));
        // console2.log("BOO", boo.balanceOf(address(sw)));
    }

    function testSwapG() external {
        sw.swap(swapDataG);
        // console2.log("WFTM", wftm.balanceOf(address(sw)));
        // console2.log("USDC", usdc.balanceOf(address(sw)));
        // console2.log("USDT", usdt.balanceOf(address(sw)));
        // console2.log("BOO", boo.balanceOf(address(sw)));
    }

    function testSwapB() external {
        sw.swap(swapDataB);
        // console2.log("WFTM", wftm.balanceOf(address(sw)));
        // console2.log("USDC", usdc.balanceOf(address(sw)));
        // console2.log("USDT", usdt.balanceOf(address(sw)));
        // console2.log("BOO", boo.balanceOf(address(sw)));
        // sw._balancerswap(amountIn,BEETHOVEN,BEETHOVEN_WFTM_USDC,WFTM,USDC,swAddress);
    }

    // function _f(uint256 x, uint256 y) internal pure returns (uint256) {
    //     return (y / 1e18 * y * y / 1e18) / 1e18 * x + (x / 1e18 * x * x / 1e18) / 1e18 * y;
    // }

    // function _d(uint256 x0, uint256 y) internal pure returns (uint256) {
    //     return 3 * x0 * (y * y / 1e18) / 1e18 + (x0 / 1e18 * x0 * x0 / 1e18);
    // }

    function _f(uint256 x0, uint256 y) internal returns (uint256) {
        uint256 left = y * y;
        left = left * y;
        left = left / 1e18;
        left = left / 1e18;
        left = x0 * left;
        left = left / 1e18;

        uint256 right = x0 * x0;
        right = right * x0;
        right = right / 1e18;
        right = right / 1e18;
        right = right * y;
        right = right / 1e18;
        console2.log("left", left);
        console2.log("right", right);
        return left + right;
    }

    function _d(uint256 x0, uint256 y) internal pure returns (uint256) {
        return 3 * x0 * (y * y / 1e18) / 1e18 + (x0 * x0 / 1e18 * x0 / 1e18);
    }

    function _get_y(uint256 x0, uint256 xy, uint256 y) public returns (uint256) {
        console2.log("x0", x0);
        console2.log("xy", xy);
        console2.log("y", y);
        for (uint256 i = 0; i < 255; i++) {
            uint256 y_prev = y;
            uint256 k = _f(x0, y);
            console2.log(i, y_prev, k);
            if (k < xy) {
                uint256 dy = (xy - k) * 1e18 / _d(x0, y);
                y = y + dy;
            } else {
                uint256 dy = (k - xy) * 1e18 / _d(x0, y);
                y = y - dy;
            }
            if (y > y_prev) {
                if (y - y_prev <= 1) {
                    return y;
                }
            } else {
                if (y_prev - y <= 1) {
                    return y;
                }
            }
        }
        return y;
    }

    uint256 reserve0 = 29_439_746;
    uint256 reserve1 = 24_458_857;
    bool stable = true;
    address token0 = 0x04068DA6C83AFCFA0e13ba15A6696662335D5B75;
    address token1 = 0x049d68029688eAbF473097a2fC38ef61633A3C7A;
    uint256 decimals0 = 1_000_000;
    uint256 decimals1 = 1_000_000;

    function getAmountOut(uint256 amountIn, address tokenIn) public returns (uint256) {
        (uint256 _reserve0, uint256 _reserve1) = (reserve0, reserve1);
        amountIn -= amountIn / 10_000; // remove fee from amount received
        return _getAmountOut(amountIn, tokenIn, _reserve0, _reserve1);
    }

    function _getAmountOut(
        uint256 amountIn,
        address tokenIn,
        uint256 _reserve0,
        uint256 _reserve1
    )
        internal
        returns (uint256)
    {
        if (stable) {
            uint256 xy = _k(_reserve0, _reserve1);
            _reserve0 = _reserve0 * 1e18 / decimals0;
            _reserve1 = _reserve1 * 1e18 / decimals1;
            (uint256 reserveA, uint256 reserveB) = tokenIn == token0 ? (_reserve0, _reserve1) : (_reserve1, _reserve0);
            amountIn = tokenIn == token0 ? amountIn * 1e18 / decimals0 : amountIn * 1e18 / decimals1;
            uint256 y = reserveB - _get_y(amountIn + reserveA, xy, reserveB);
            return y * (tokenIn == token0 ? decimals1 : decimals0) / 1e18;
        } else {
            (uint256 reserveA, uint256 reserveB) = tokenIn == token0 ? (_reserve0, _reserve1) : (_reserve1, _reserve0);
            return amountIn * reserveB / (reserveA + amountIn);
        }
    }

    function _k(uint256 x, uint256 y) internal view returns (uint256) {
        if (stable) {
            uint256 _x = x * 1e18 / decimals0;
            uint256 _y = y * 1e18 / decimals1;
            uint256 _a = (_x * _y) / 1e18;
            uint256 _b = ((_x * _x) / 1e18 + (_y * _y) / 1e18);
            return _a * _b / 1e18; // x3y+y3x >= k
        } else {
            return x * y; // xy >= k
        }
    }

    function testFD() external {
        uint256 _y = getAmountOut(1_000_000, token0);
        console.log("_y", _y);
    }
    // function testSwapGMX() external {
    //     sw.transfer(WFTM, amountIn, gmAdd);
    // //     console2.log("CONTRACT->GMX WFTM:", amountIn);
    // //     amountIn = sw._gmxswap(address(mmVault), WFTM, USDC, EQUALIZER_USDC_USDT_LP);
    //     sw._gmxswap(gmAdd,WFTM,USDC,swAddress);
    //     // console2.log("WFTM", wftm.balanceOf(address(sw)));
    //     // console2.log("USDC", usdc.balanceOf(address(sw)));
    //     // console2.log("USDT", usdt.balanceOf(address(sw)));
    //     // console2.log("BOO", boo.balanceOf(address(sw)));
    // }
}

// 3111.373701 SPOOKY
// 3111.373701 EQUALIZER
// 3112.998786 MUMMY
// 578897.335687
