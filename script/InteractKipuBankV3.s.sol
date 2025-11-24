// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {KipuBankV3} from "../src/KipuBankV3.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract InteractKipuBankV3 is Script {
    // =============================================================
    // CONFIGURACIÓN
    // =============================================================
    
    // ⚠️ IMPORTANTE: Una vez que despliegues el contrato (usando DeployKipuBankV3),
    // copia la dirección que te dé la terminal y pégala aquí:
    address constant KIPU_BANK_ADDRESS = 0x0000000000000000000000000000000000000000; 
    
    // Dirección de DAI en Sepolia (para probar depósitos de tokens)
    address constant DAI_SEPOLIA = 0x68194a729C2450ad26072b3D33ADaCbcef39D574;

    function run() external {
        // Obtenemos la llave privada del .env
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Empezamos la transmisión de transacciones
        vm.startBroadcast(deployerPrivateKey);

        KipuBankV3 kipuBank = KipuBankV3(payable(KIPU_BANK_ADDRESS));

        // ---------------------------------------------------------
        // INTERACCIÓN 1: Depositar ETH
        // ---------------------------------------------------------
        // Intentamos depositar 0.001 ETH
        // Tu contrato automáticamente hará el swap a USDC
        console.log("Interactuando con KipuBank en:", address(kipuBank));
        console.log("Depositando 0.001 ETH...");
        
        kipuBank.depositETH{value: 0.001 ether}();
        
        console.log("Deposito de ETH enviado con exito.");

        // ---------------------------------------------------------
        // INTERACCIÓN 2: Leer Estadísticas
        // ---------------------------------------------------------
        (uint256 totalUSDC, uint256 remainingCap,,,) = kipuBank.getBankStats();
        
        console.log("--- Estadisticas Actuales ---");
        console.log("Total USDC gestionado:", totalUSDC);
        console.log("Capacidad restante:", remainingCap);

        vm.stopBroadcast();
    }

    /**
     * @notice Función auxiliar para aprobar y depositar un token ERC20
     * @dev Úsala si tienes tokens (como DAI) en tu wallet de prueba
     */
    function depositERC20(address token, uint256 amount) public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        KipuBankV3 kipuBank = KipuBankV3(payable(KIPU_BANK_ADDRESS));
        
        // 1. Aprobar
        IERC20(token).approve(address(kipuBank), amount);
        
        // 2. Depositar
        kipuBank.depositToken(token, amount);
        
        vm.stopBroadcast();
    }
}