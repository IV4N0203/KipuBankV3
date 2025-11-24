// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {KipuBankV3} from "../src/KipuBankV3.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract KipuBankV3IntegrationTest is Test {
    KipuBankV3 public kipuBank;

    // ==========================================
    // DIRECCIONES REALES DE SEPOLIA
    // ==========================================
    address constant USDC_SEPOLIA = 0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8;
    address constant DAI_SEPOLIA = 0x68194a729C2450ad26072b3D33ADaCbcef39D574;
    address constant ROUTER_SEPOLIA = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    // Configuración del banco
    uint256 constant BANK_CAP = 1_000_000 * 1e6; 
    uint256 constant WITHDRAWAL_LIMIT = 10_000 * 1e6;

    // Variable para controlar si estamos en un Fork
    bool public isForked;

    function setUp() public {
        // Intentamos leer la URL de RPC del archivo .env
        // Nota: Si falla aquí con "envString not found", asegúrate de tener SEPOLIA_RPC_URL en tu .env
        try vm.envString("SEPOLIA_RPC_URL") returns (string memory rpcUrl) {
            // 1. Crear el Fork (Clonar la blockchain de Sepolia en este momento)
            vm.createSelectFork(rpcUrl);
            isForked = true;

            // 2. Desplegar tu contrato en este entorno clonado
            kipuBank = new KipuBankV3(
                BANK_CAP,
                WITHDRAWAL_LIMIT,
                ROUTER_SEPOLIA,
                USDC_SEPOLIA
            );
            
            // 3. Agregar soporte para ETH y DAI en tu banco
            kipuBank.addETHSupport();
            kipuBank.addSupportedToken(DAI_SEPOLIA, true); // true = requiere swap
            
        } catch {
            console.log(" ADVERTENCIA: No se encontro SEPOLIA_RPC_URL. Saltando tests de integracion.");
        }
    }

    /**
     * @notice Prueba un depósito real de ETH convirtiéndose a USDC via Uniswap
     */
    function testFork_DepositETHToUSDC() public {
        if (!isForked) return; // Si no hay fork, no hacemos nada

        address user = makeAddr("usuarioRico");
        vm.deal(user, 10 ether); // Darle 10 ETH mágicos al usuario

        vm.startPrank(user);
        
        uint256 amountDeposit = 0.1 ether;
        
        // Verificar saldo antes
        uint256 balanceAntes = kipuBank.getUserBalance(user);
        assertEq(balanceAntes, 0);

        // Ejecutar depósito
        console.log("Depositando 0.1 ETH en entorno Fork...");
        kipuBank.depositETH{value: amountDeposit}();

        // Verificar saldo después
        uint256 balanceDespues = kipuBank.getUserBalance(user);
        
        console.log("USDC Recibido:", balanceDespues);
        
        // Deberíamos tener más de 0 USDC
        assertGt(balanceDespues, 0);
        
        vm.stopPrank();
    }

    /**
     * @notice Prueba un depósito real de DAI convirtiéndose a USDC via Uniswap
     */
    function testFork_DepositDAIToUSDC() public {
        if (!isForked) return;

        address user = makeAddr("usuarioDai");
        uint256 amountDai = 100 * 1e18; // 100 DAI

        // CHEATCODE MAGICO: 'deal'
        // Le damos 100 DAI reales al usuario (modificando el almacenamiento del contrato DAI)
        deal(DAI_SEPOLIA, user, amountDai);

        vm.startPrank(user);

        // Aprobar al banco
        IERC20(DAI_SEPOLIA).approve(address(kipuBank), amountDai);

        // Depositar
        console.log("Depositando 100 DAI en entorno Fork...");
        kipuBank.depositToken(DAI_SEPOLIA, amountDai);

        uint256 usdcBalance = kipuBank.getUserBalance(user);
        console.log("USDC Recibido por los DAI:", usdcBalance);

        assertGt(usdcBalance, 0);

        vm.stopPrank();
    }
}