// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Auction
 * @dev Contrato de subasta con reembolsos parciales y extensión automática de tiempo
 * @author Wilver Arriaza
 */
contract Auction {
    // ============ VARIABLES DE ESTADO ============
    
    address public immutable owner;        // Propietario de la subasta
    address public immutable beneficiary; // Beneficiario de la subasta
    uint256 public immutable auctionEndTime; // Tiempo inicial de finalización
    uint256 public actualEndTime;         // Tiempo actual de finalización (puede extenderse)
    string public itemDescription;        // Descripción del artículo
    
    address public highestBidder;         // Mejor oferente actual
    uint256 public highestBid;           // Mejor oferta actual
    
    // Mapeo de oferentes a sus ofertas totales depositadas
    mapping(address => uint256) public pendingReturns;
    
    // Array para mantener registro de todos los oferentes
    address[] public bidders;
    mapping(address => bool) public hasBid; // Para evitar duplicados en el array
    
    // Array para mantener historial de ofertas
    struct BidHistory {
        address bidder;
        uint256 amount;
        uint256 timestamp;
    }
    BidHistory[] public bidHistory;
    
    bool public ended = false;           // Estado de la subasta
    
    // Constantes
    uint256 public constant MINIMUM_INCREMENT_PERCENTAGE = 5; // 5%
    uint256 public constant COMMISSION_PERCENTAGE = 2;        // 2%
    uint256 public constant TIME_EXTENSION = 10 minutes;      // Extensión de tiempo
    uint256 public constant EXTENSION_THRESHOLD = 10 minutes; // Umbral para extensión
    
    // ============ EVENTOS ============
    
    event NuevaOferta(address indexed bidder, uint256 amount, uint256 timestamp);
    event SubastaFinalizada(address winner, uint256 amount);
    event TiempoExtendido(uint256 newEndTime);
    event ReembolsoRealizado(address indexed bidder, uint256 amount);
    
    // ============ MODIFICADORES ============
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Solo el propietario puede ejecutar esta funcion");
        _;
    }
    
    modifier auctionActive() {
        require(block.timestamp < actualEndTime, "La subasta ha finalizado");
        require(!ended, "La subasta ha sido finalizada manualmente");
        _;
    }
    
    modifier auctionEnded() {
        require(block.timestamp >= actualEndTime || ended, "La subasta aun esta activa");
        _;
    }
    
    modifier validBid() {
        require(msg.value > 0, "La oferta debe ser mayor a 0");
        if (highestBid > 0) {
            uint256 minimumBid = highestBid + (highestBid * MINIMUM_INCREMENT_PERCENTAGE / 100);
            require(msg.value >= minimumBid, "La oferta debe ser al menos 5% mayor que la actual");
        }
        _;
    }
    
    // ============ CONSTRUCTOR ============
    
    /**
     * @dev Constructor para inicializar la subasta
     * @param _biddingTime Duración de la subasta en segundos
     * @param _beneficiary Dirección que recibirá el pago final
     * @param _itemDescription Descripción del artículo en subasta
     */
    constructor(
        uint256 _biddingTime,
        address _beneficiary,
        string memory _itemDescription
    ) {
        require(_beneficiary != address(0), "Beneficiario no puede ser direccion cero");
        require(_biddingTime > 0, "El tiempo de subasta debe ser mayor a 0");
        require(bytes(_itemDescription).length > 0, "Descripcion del articulo requerida");
        
        owner = msg.sender;
        beneficiary = _beneficiary;
        auctionEndTime = block.timestamp + _biddingTime;
        actualEndTime = auctionEndTime;
        itemDescription = _itemDescription;
    }
    
    // ============ FUNCIONES PRINCIPALES ============
    
    /**
     * @dev Función para realizar una oferta
     */
    function bid() external payable auctionActive validBid {
        // Si no es el primer oferente de esta dirección, agregar al reembolso pendiente
        if (pendingReturns[msg.sender] > 0) {
            pendingReturns[msg.sender] += msg.value;
        } else {
            pendingReturns[msg.sender] = msg.value;
            // Agregar al array de oferentes si es la primera vez
            if (!hasBid[msg.sender]) {
                bidders.push(msg.sender);
                hasBid[msg.sender] = true;
            }
        }
        
        // Si había una oferta anterior, agregar al reembolso del oferente anterior
        if (highestBidder != address(0)) {
            pendingReturns[highestBidder] = pendingReturns[highestBidder] - highestBid + msg.value;
            pendingReturns[msg.sender] = msg.value;
        }
        
        // Actualizar la mejor oferta
        highestBidder = msg.sender;
        highestBid = msg.value;
        
        // Agregar al historial
        bidHistory.push(BidHistory({
            bidder: msg.sender,
            amount: msg.value,
            timestamp: block.timestamp
        }));
        
        // Verificar si necesita extensión de tiempo
        if (actualEndTime - block.timestamp <= EXTENSION_THRESHOLD) {
            actualEndTime += TIME_EXTENSION;
            emit TiempoExtendido(actualEndTime);
        }
        
        emit NuevaOferta(msg.sender, msg.value, block.timestamp);
    }
    
    /**
     * @dev Permite a los oferentes retirar el exceso sobre su oferta actual
     */
    function withdrawExcess() external {
        uint256 amount = 0;
        
        if (msg.sender == highestBidder) {
            // El oferente ganador actual puede retirar todo excepto su oferta ganadora
            amount = pendingReturns[msg.sender] - highestBid;
        } else {
            // Los no ganadores pueden retirar todo
            amount = pendingReturns[msg.sender];
        }
        
        require(amount > 0, "No hay fondos para retirar");
        
        // Actualizar el estado antes de la transferencia (CEI pattern)
        pendingReturns[msg.sender] -= amount;
        
        // Transferir fondos
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Fallo en la transferencia");
        
        emit ReembolsoRealizado(msg.sender, amount);
    }
    
    /**
     * @dev Finaliza la subasta y procesa los reembolsos
     */
    function endAuction() external auctionEnded {
        require(!ended, "La subasta ya ha sido finalizada");
        
        ended = true;
        emit SubastaFinalizada(highestBidder, highestBid);
        
        // Transferir la ganancia al beneficiario si hay ganador
        if (highestBidder != address(0)) {
            (bool success, ) = beneficiary.call{value: highestBid}("");
            require(success, "Fallo en transferencia al beneficiario");
        }
    }
    
    /**
     * @dev Permite a los oferentes no ganadores retirar sus depósitos con comisión
     */
    function withdraw() external auctionEnded {
        require(ended, "La subasta debe estar finalizada");
        require(msg.sender != highestBidder, "El ganador no puede retirar");
        
        uint256 amount = pendingReturns[msg.sender];
        require(amount > 0, "No hay fondos para retirar");
        
        // Calcular comisión del 2%
        uint256 commission = (amount * COMMISSION_PERCENTAGE) / 100;
        uint256 refundAmount = amount - commission;
        
        // Actualizar estado antes de transferencia
        pendingReturns[msg.sender] = 0;
        
        // Transferir fondos menos comisión
        (bool success, ) = msg.sender.call{value: refundAmount}("");
        require(success, "Fallo en la transferencia");
        
        // Transferir comisión al propietario
        (bool commissionSuccess, ) = owner.call{value: commission}("");
        require(commissionSuccess, "Fallo en transferencia de comision");
        
        emit ReembolsoRealizado(msg.sender, refundAmount);
    }
    
    // ============ FUNCIONES DE VISTA ============
    
    /**
     * @dev Devuelve el ganador actual y el monto de la oferta ganadora
     */
    function getWinner() external view returns (address winner, uint256 winningBid) {
        return (highestBidder, highestBid);
    }
    
    /**
     * @dev Devuelve la información completa del ganador
     */
    function getWinnerInfo() external view returns (
        address winner,
        uint256 winningBid,
        bool auctionIsEnded
    ) {
        return (highestBidder, highestBid, ended || block.timestamp >= actualEndTime);
    }
    
    /**
     * @dev Devuelve todos los oferentes y sus montos totales depositados
     */
    function getAllBidders() external view returns (address[] memory, uint256[] memory) {
        uint256[] memory amounts = new uint256[](bidders.length);
        
        for (uint256 i = 0; i < bidders.length; i++) {
            amounts[i] = pendingReturns[bidders[i]];
        }
        
        return (bidders, amounts);
    }
    
    /**
     * @dev Devuelve el historial completo de ofertas
     */
    function getBidHistory() external view returns (
        address[] memory bidders,
        uint256[] memory amounts,
        uint256[] memory timestamps
    ) {
        uint256 length = bidHistory.length;
        bidders = new address[](length);
        amounts = new uint256[](length);
        timestamps = new uint256[](length);
        
        for (uint256 i = 0; i < length; i++) {
            bidders[i] = bidHistory[i].bidder;
            amounts[i] = bidHistory[i].amount;
            timestamps[i] = bidHistory[i].timestamp;
        }
        
        return (bidders, amounts, timestamps);
    }
    
    /**
     * @dev Devuelve información detallada de la subasta
     */
    function getAuctionInfo() external view returns (
        string memory description,
        uint256 startTime,
        uint256 originalEndTime,
        uint256 currentEndTime,
        bool isActive,
        bool hasEnded,
        uint256 totalBidders,
        uint256 totalBids
    ) {
        return (
            itemDescription,
            auctionEndTime - (actualEndTime - auctionEndTime), // Tiempo de inicio aproximado
            auctionEndTime,
            actualEndTime,
            block.timestamp < actualEndTime && !ended,
            ended || block.timestamp >= actualEndTime,
            bidders.length,
            bidHistory.length
        );
    }
    
    /**
     * @dev Devuelve el monto mínimo para la siguiente oferta
     */
    function getMinimumBid() external view returns (uint256) {
        if (highestBid == 0) {
            return 1; // Mínimo 1 wei para la primera oferta
        }
        return highestBid + (highestBid * MINIMUM_INCREMENT_PERCENTAGE / 100);
    }
    
    /**
     * @dev Devuelve el tiempo restante de la subasta
     */
    function getTimeRemaining() external view returns (uint256) {
        if (block.timestamp >= actualEndTime || ended) {
            return 0;
        }
        return actualEndTime - block.timestamp;
    }
    
    /**
     * @dev Devuelve el saldo pendiente de retiro para una dirección
     */
    function getPendingReturn(address bidder) external view returns (uint256) {
        return pendingReturns[bidder];
    }
    
    /**
     * @dev Devuelve si una dirección puede retirar fondos y cuánto
     */
    function getWithdrawableAmount(address bidder) external view returns (uint256) {
        if (bidder == highestBidder && (!ended && block.timestamp < actualEndTime)) {
            // El oferente ganador actual puede retirar el exceso
            return pendingReturns[bidder] > highestBid ? pendingReturns[bidder] - highestBid : 0;
        } else if (ended || block.timestamp >= actualEndTime) {
            // Después de finalizar, los no ganadores pueden retirar todo (menos comisión)
            if (bidder != highestBidder) {
                uint256 amount = pendingReturns[bidder];
                uint256 commission = (amount * COMMISSION_PERCENTAGE) / 100;
                return amount > commission ? amount - commission : 0;
            }
        } else {
            // Durante la subasta, no ganadores pueden retirar todo
            return pendingReturns[bidder];
        }
        return 0;
    }
    
    // ============ FUNCIONES DE ADMINISTRACIÓN ============
    
    /**
     * @dev Permite al propietario finalizar la subasta manualmente (solo en emergencias)
     */
    function emergencyEndAuction() external onlyOwner {
        require(!ended, "La subasta ya ha finalizado");
        ended = true;
        emit SubastaFinalizada(highestBidder, highestBid);
    }
    
    /**
     * @dev Permite al propietario retirar comisiones acumuladas
     */
    function withdrawCommissions() external onlyOwner {
        require(ended, "La subasta debe estar finalizada");
        uint256 balance = address(this).balance;
        
        // Calcular el total que debería estar en el contrato (sin comisiones)
        uint256 expectedBalance = 0;
        if (highestBidder != address(0)) {
            expectedBalance += highestBid; // Oferta ganadora ya transferida
        }
        
        for (uint256 i = 0; i < bidders.length; i++) {
            if (bidders[i] != highestBidder) {
                expectedBalance += pendingReturns[bidders[i]];
            }
        }
        
        // Las comisiones son la diferencia
        if (balance > expectedBalance) {
            uint256 commissions = balance - expectedBalance;
            (bool success, ) = owner.call{value: commissions}("");
            require(success, "Fallo en transferencia de comisiones");
        }
    }
    
    // ============ FUNCIONES DE SEGURIDAD ============
    
    /**
     * @dev Función de emergencia para recuperar fondos bloqueados (solo owner)
     */
    function emergencyWithdraw() external onlyOwner {
        require(ended && block.timestamp > actualEndTime + 30 days, 
                "Solo disponible 30 dias despues del fin de la subasta");
        
        (bool success, ) = owner.call{value: address(this).balance}("");
        require(success, "Fallo en transferencia de emergencia");
    }
    
    /**
     * @dev Función para verificar el estado del contrato
     */
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
    
    /**
     * @dev Prevenir recepción directa de Ether
     */
    receive() external payable {
        revert("Use la funcion bid() para participar en la subasta");
    }
    
    fallback() external payable {
        revert("Funcion no existe");
    }
}
