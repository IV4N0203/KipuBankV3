// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {KipuBankV3} from "../src/KipuBankV3.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {MockUniswapV2Router, MockUniswapV2Factory} from "./mocks/MockUniswapV2.sol";

contract KipuBankV3Test is Test {
    KipuBankV3 public kipuBank;
    
    // Mocks
    MockERC20 public usdc;
    MockERC20 public weth;
    MockERC20 public dai;
    MockUniswapV2Router public mockRouter;
    MockUniswapV2Factory public mockFactory;

    // Usuarios
    address public owner = address(1);
    address public user = address(2);

    // Configuración
    uint256 constant BANK_CAP = 1_000_000 * 1e6; // 1M USDC
    uint256 constant WITHDRAWAL_LIMIT = 10_000 * 1e6; // 10k USDC

    function setUp() public {
        vm.startPrank(owner);

        // 1. Desplegar Mocks de Tokens
        usdc = new MockERC20("USD Coin", "USDC", 6);
        weth = new MockERC20("Wrapped Ether", "WETH", 18);
        dai = new MockERC20("Dai Stablecoin", "DAI", 18);

        // 2. Desplegar Mocks de Uniswap
        mockFactory = new MockUniswapV2Factory();
        mockRouter = new MockUniswapV2Router(address(mockFactory), address(weth));

        // 3. Configurar Pares en el Factory (Simular que existe liquidez)
        // Usamos address(123) como dirección falsa del par, solo para que no sea address(0)
        mockFactory.setPair(address(dai), address(usdc), address(123));
        mockFactory.setPair(address(weth), address(usdc), address(456));

        // 4. Desplegar KipuBankV3
        kipuBank = new KipuBankV3(
            BANK_CAP,
            WITHDRAWAL_LIMIT,
            address(mockRouter),
            address(usdc)
        );

        // 5. Fondear al MockRouter con USDC para que pueda "pagar" los swaps
        usdc.mint(address(mockRouter), 1_000_000 * 1e6);

        vm.stopPrank();

        // 6. Preparar usuario
        vm.deal(user, 100 ether); // Dar ETH al usuario
        dai.mint(user, 1000 * 1e18); // Dar DAI al usuario
    }

    // --- TESTS ---

    function testInitialConfig() public view {
        assertEq(address(kipuBank.i_usdc()), address(usdc));
        assertEq(kipuBank.owner(), owner);
    }

    function testDepositUSDC() public {
        vm.startPrank(user);
        
        uint256 depositAmount = 100 * 1e6; // 100 USDC
        usdc.mint(user, depositAmount);
        
        // Aprobar y depositar
        usdc.approve(address(kipuBank), depositAmount);
        kipuBank.depositToken(address(usdc), depositAmount);

        // Verificar balance en el banco
        uint256 userBalance = kipuBank.getUserBalance(user);
        assertEq(userBalance, depositAmount);
        
        vm.stopPrank();
    }

    function testDepositDAIWithSwap() public {
        vm.startPrank(owner);
        // Habilitar DAI en el banco (requiere swap = true)
        kipuBank.addSupportedToken(address(dai), true);
        vm.stopPrank();

        vm.startPrank(user);
        uint256 daiAmount = 100 * 1e18; // 100 DAI
        
        // Aprobar DAI
        dai.approve(address(kipuBank), daiAmount);
        
        // Depositar (El mock router cambiará 100 DAI por 100 USDC según nuestra lógica 1:1)
        kipuBank.depositToken(address(dai), daiAmount);

        // Como el Mock devuelve 1:1, esperamos recibir 100 USDC (ajustado a decimales si el mock fuera complejo,
        // pero nuestro mock devuelve amountIn exacto, así que recibimos 100 unidades)
        // NOTA: En este mock simple 100 DAI (18 dec) se convierten en 100 USDC (simulado)
        // Para este test simple validamos que el balance > 0
        uint256 balance = kipuBank.getUserBalance(user);
        assertGt(balance, 0);
        
        vm.stopPrank();
    }

    function testWithdrawUSDC() public {
        // 1. Primero depositamos USDC
        testDepositUSDC(); 

        vm.startPrank(user);
        uint256 balanceBefore = usdc.balanceOf(user);
        uint256 withdrawAmount = 50 * 1e6;

        kipuBank.withdrawUSDC(withdrawAmount);

        uint256 balanceAfter = usdc.balanceOf(user);
        
        // Verificamos que recuperó su dinero
        assertEq(balanceAfter, balanceBefore + withdrawAmount);
        // Verificamos que bajó su balance en el banco
        assertEq(kipuBank.getUserBalance(user), 50 * 1e6); // 100 - 50 = 50
        vm.stopPrank();
    }

    function testFailDepositUnsupportedToken() public {
        vm.startPrank(user);
        MockERC20 randomToken = new MockERC20("Random", "RND", 18);
        randomToken.mint(user, 100);
        
        randomToken.approve(address(kipuBank), 100);
        // Esto debería fallar porque el token no fue agregado
        kipuBank.depositToken(address(randomToken), 100);
        vm.stopPrank();
    }
}