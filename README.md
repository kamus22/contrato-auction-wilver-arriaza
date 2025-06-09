# 🎯 Smart Contract de Subasta - Auction

Un contrato inteligente avanzado de subasta implementado en Solidity que incluye reembolsos parciales, extensión automática de tiempo y comisiones.

## 📋 Características Principales

- ✅ Ofertas con incremento mínimo del 5%
- ✅ Extensión automática de tiempo (10 minutos si se oferta en los últimos 10 minutos)
- ✅ Reembolsos parciales durante la subasta
- ✅ Sistema de comisiones del 2%
- ✅ Historial completo de ofertas
- ✅ Funciones de emergencia y seguridad
- ✅ Eventos para seguimiento en tiempo real

## 🏗️ Arquitectura del Contrato

### Variables de Estado

#### Variables Principales
- `address public immutable owner` - Propietario del contrato
- `address public immutable beneficiary` - Receptor de la oferta ganadora
- `uint256 public immutable auctionEndTime` - Tiempo original de finalización
- `uint256 public actualEndTime` - Tiempo actual de finalización (puede extenderse)
- `string public itemDescription` - Descripción del artículo en subasta

#### Estado de la Subasta
- `address public highestBidder` - Oferente con la mayor oferta actual
- `uint256 public highestBid` - Valor de la oferta más alta
- `bool public ended` - Estado de finalización de la subasta

#### Gestión de Oferentes
- `mapping(address => uint256) public pendingReturns` - Depósitos pendientes por dirección
- `address[] public bidders` - Lista de todos los oferentes
- `mapping(address => bool) public hasBid` - Control de oferentes únicos
- `BidHistory[] public bidHistory` - Historial completo de ofertas

#### Constantes
- `MINIMUM_INCREMENT_PERCENTAGE = 5` - Incremento mínimo del 5%
- `COMMISSION_PERCENTAGE = 2` - Comisión del 2%
- `TIME_EXTENSION = 10 minutes` - Extensión de tiempo
- `EXTENSION_THRESHOLD = 10 minutes` - Umbral para activar extensión

### Estructuras de Datos

#### BidHistory
```solidity
struct BidHistory {
    address bidder;    // Dirección del oferente
    uint256 amount;    // Monto de la oferta
    uint256 timestamp; // Momento de la oferta
}
```

## 🚀 Funciones Principales

### Constructor
```solidity
constructor(uint256 _biddingTime, address _beneficiary, string memory _itemDescription)
```
Inicializa la subasta con:
- `_biddingTime`: Duración en segundos
- `_beneficiary`: Dirección que recibirá la oferta ganadora
- `_itemDescription`: Descripción del artículo

### Función de Oferta
```solidity
function bid() external payable auctionActive validBid
```
- Permite realizar ofertas durante la subasta activa
- Valida incremento mínimo del 5%
- Extiende tiempo automáticamente si es necesario
- Actualiza el historial de ofertas

### Reembolsos Parciales
```solidity
function withdrawExcess() external
```
- Permite retirar el exceso sobre la oferta actual
- Oferente ganador: puede retirar todo excepto su oferta ganadora
- Otros oferentes: pueden retirar todo su depósito

### Finalización
```solidity
function endAuction() external auctionEnded
```
- Finaliza la subasta
- Transfiere la oferta ganadora al beneficiario
- Emite evento de finalización

### Retiro de Depósitos
```solidity
function withdraw() external auctionEnded
```
- Permite a oferentes no ganadores retirar sus depósitos
- Aplica comisión del 2%
- Solo disponible después de finalizar la subasta

## 👁️ Funciones de Vista

### Información del Ganador
- `getWinner()` - Devuelve ganador actual y oferta
- `getWinnerInfo()` - Información completa del ganador

### Información de Oferentes
- `getAllBidders()` - Lista todos los oferentes y sus montos
- `getBidHistory()` - Historial completo de ofertas
- `getPendingReturn(address)` - Saldo pendiente de una dirección

### Información de la Subasta
- `getAuctionInfo()` - Información detallada de la subasta
- `getMinimumBid()` - Monto mínimo para la siguiente oferta
- `getTimeRemaining()` - Tiempo restante
- `getWithdrawableAmount(address)` - Monto retirable para una dirección

## 🔧 Modificadores

### onlyOwner
Restringe acceso al propietario del contrato

### auctionActive
Valida que la subasta esté activa:
- Tiempo no expirado
- No finalizada manualmente

### auctionEnded
Valida que la subasta haya terminado

### validBid
Valida ofertas:
- Monto mayor a 0
- Incremento mínimo del 5% (si no es la primera oferta)

## 📢 Eventos

### NuevaOferta
```solidity
event NuevaOferta(address indexed bidder, uint256 amount, uint256 timestamp);
```
Emitido cuando se realiza una nueva oferta

### SubastaFinalizada
```solidity
event SubastaFinalizada(address winner, uint256 amount);
```
Emitido cuando finaliza la subasta

### TiempoExtendido
```solidity
event TiempoExtendido(uint256 newEndTime);
```
Emitido cuando se extiende el tiempo de la subasta

### ReembolsoRealizado
```solidity
event ReembolsoRealizado(address indexed bidder, uint256 amount);
```
Emitido cuando se realiza un reembolso

## 🛡️ Características de Seguridad

### Protección contra Reentrancia
- Uso del patrón CEI (Checks-Effects-Interactions)
- Actualización de estado antes de transferencias externas

### Validaciones Robustas
- Verificación de direcciones válidas
- Validación de montos y tiempos
- Control de estados de la subasta

### Funciones de Emergencia
```solidity
function emergencyEndAuction() external onlyOwner
```
Permite al propietario finalizar la subasta manualmente

```solidity
function emergencyWithdraw() external onlyOwner
```
Recuperación de fondos después de 30 días de finalizada la subasta

### Prevención de Transferencias Directas
- `receive()` y `fallback()` revierten transferencias directas
- Fuerza el uso de la función `bid()`

## 💡 Ejemplos de Uso

### Despliegue del Contrato
```javascript
// Duración: 5 días global (432000 segundos)
// Beneficiario: 0x13FFe7Bbe3709baDFaF9ca06721d59dda1f1ddE2
// Descripción: Obra de arte digital única
const auction = await Auction.deploy(
    3600,
    "0x742d35Cc6635C0532925a3b8D7389C7b8b1c6c3f",
    "Obra de arte digital única"
);
```

### Realizar una Oferta
```javascript
// Oferta de 1 ETH
await auction.bid({ value: ethers.utils.parseEther("1.0") });
```

### Consultar Información
```javascript
// Obtener ganador actual
const [winner, amount] = await auction.getWinner();

// Verificar tiempo restante
const timeLeft = await auction.getTimeRemaining();

// Ver historial de ofertas
const [bidders, amounts, timestamps] = await auction.getBidHistory();
```

### Retirar Fondos
```javascript
// Durante la subasta (reembolso parcial)
await auction.withdrawExcess();

// Después de la subasta (con comisión)
await auction.withdraw();
```

## 🔄 Flujo de la Subasta

### 1. Inicio
- Despliegue del contrato con parámetros iniciales
- La subasta comienza inmediatamente

### 2. Fase de Ofertas
- Los participantes pueden ofertar con incremento mínimo del 5%
- Cada oferta puede extender el tiempo si se realiza en los últimos 10 minutos
- Los oferentes pueden retirar excesos de sus depósitos

### 3. Extensiones Automáticas
- Si una oferta válida se realiza en los últimos 10 minutos
- El tiempo se extiende automáticamente 10 minutos más
- Se emite evento `TiempoExtendido`

### 4. Finalización
- La subasta finaliza automáticamente cuando expira el tiempo
- O manualmente usando `endAuction()`
- La oferta ganadora se transfiere al beneficiario

### 5. Retiros Post-Subasta
- Oferentes no ganadores pueden retirar con comisión del 2%
- El propietario puede retirar comisiones acumuladas

## ⚠️ Consideraciones Importantes

### Gas y Eficiencia
- Las funciones de vista no consumen gas
- Las operaciones de escritura están optimizadas
- Uso de eventos para reducir costos de almacenamiento

### Manejo de Errores
- Todos los errores incluyen mensajes descriptivos
- Validaciones exhaustivas en todas las funciones públicas
- Reversión segura en casos de fallo

### Limitaciones
- Una vez finalizada, la subasta no puede reanudarse
- Las ofertas no pueden ser canceladas (solo reembolsos parciales)
- El propietario no puede modificar parámetros después del despliegue

## 🧪 Testing y Verificación

### Casos de Prueba Esenciales

1. **Ofertas Válidas**
   - Primera oferta con cualquier monto
   - Ofertas subsecuentes con incremento mínimo del 5%

2. **Validaciones**
   - Rechazo de ofertas menores al 5% de incremento
   - Bloqueo de ofertas después de finalización

3. **Extensiones de Tiempo**
   - Verificar extensión cuando se oferta en últimos 10 minutos
   - Comprobar que no se extiende si la oferta es anterior

4. **Reembolsos**
   - Reembolsos parciales durante la subasta
   - Reembolsos con comisión después de finalizar

5. **Seguridad**
   - Protección contra reentrancia
   - Validación de permisos de propietario

## 📦 Estructura de Archivos

```
SUBASTA/
├── Auction.sol          # Contrato principal
├── README.md           # Documentación completa
```

## 🚀 Deployment

### Remix IDE
1. Copiar el código de `Auction.sol`
2. Compilar con Solidity ^0.8.29
3. Desplegar con parámetros apropiados

---

## 📄 Licencia

MIT License - Ver archivo LICENSE para más detalles.

## 👨‍💻 Desarrollado por

Wilver Arriaza

---
