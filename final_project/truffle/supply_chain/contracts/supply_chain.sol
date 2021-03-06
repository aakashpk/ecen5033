pragma solidity ^0.5.0;
// Needed to pass in array-of-struct parameters
pragma experimental ABIEncoderV2;

contract SupplyChain {

    /*
    Every "supplier" has an "inventory" full of "items".
    Every "designer" has a "product registry" full of "products".
    Each "product" is an array of "parts".
    A "part" is either a "product" or "item".
    */

    // ---------- Inventory section --------------

    struct PriceStruct {
        uint quantity;
        uint priceWei;
    }

    struct Item {
        //id; // ID tracked in higher-level data structure
        uint quantityAvailable;
        uint dummy; // Amazing that this is required to get code to work
        bytes32 hashedDescription;
        PriceStruct[] prices; // Probably don't need to specify "storage" type. Seems implied.
    }

    struct Inventory {
        uint numItems; // this will act as an ID.
        bool available;
        mapping (uint => Item) items;
    }

    // Supplier inventories tied to their owner address
    // Notes on working with mapping of contracts:
    // https://ethereum.stackexchange.com/questions/32354/mapping-to-contract
    mapping (address => Inventory) public inventories;

    function addItem(uint quantity, bytes32 description, PriceStruct[] memory priceArray) public {
        if (!inventories[msg.sender].available) {
            inventories[msg.sender].available = true;
            // Unnecessary now that we're using structs instead of contracts
            //inventories[msg.sender] = new Inventory();
        }

        // Helper references to save typing
        Inventory storage inventory = inventories[msg.sender];
        Item storage item = inventory.items[inventory.numItems];

        item.quantityAvailable = quantity;
        item.hashedDescription = description;

        for (uint i = 0; i < priceArray.length; i++) {
            item.prices.push(priceArray[i]);
        }

        inventory.numItems++;
    }

    // Cannot return values from non-pure/view functions, so can't get ID from addItem call.
    function getNextItemId() public view returns (uint) {
        if (inventories[msg.sender].available) {
            return inventories[msg.sender].numItems;
        } else {
            return 0; // Next id will be zero if inventory does not exist yet
        }
        // Todo - modify to zero by default if not available
    }

    function getPreviousItemId() public view returns (uint) {
        if (inventories[msg.sender].available && inventories[msg.sender].numItems != 0) {
            return inventories[msg.sender].numItems - 1;
        } else {
            return ~uint(0); // largest uint
        }
    }

    function replaceQuantity(uint itemId, uint newQuantity) public {
        require(inventories[msg.sender].available, "Inventory not available");
        inventories[msg.sender].items[itemId].quantityAvailable = newQuantity;
    }

    // Suspected atomicity issues between reading quantity and calling replace.
    // So also allowing "increment", which may also be negative.
    // Considering renaming increment to "adjustQuantity".
    /* Type conversion issues means it's easier to just create two separate functions
    function incrementQuantity(uint itemId, int increment) public {
        inventories[msg.sender].items[itemId].quantityAvailable += increment;
    }
    */
    function incrementQuantity(uint itemId, uint increment) public {
        require(inventories[msg.sender].available, "Inventory not available");
        inventories[msg.sender].items[itemId].quantityAvailable += increment;
    }
    function decrementQuantity(uint itemId, uint decrement) public {
        require(inventories[msg.sender].available, "Inventory not available");
        inventories[msg.sender].items[itemId].quantityAvailable -= decrement;
    }


    function replacePrices(uint itemId, PriceStruct[] memory priceArray) public {
        require(inventories[msg.sender].available, "Inventory not available");

        // Helper references to save typing
        Inventory storage inventory = inventories[msg.sender];
        Item storage item = inventory.items[inventory.numItems];


        // Direct copy not supported: https://github.com/ethereum/solidity/issues/3446
        //item.prices = priceArray;
        // Must use loop instead:
        // Delete array first. This just sets all elements to zero
        delete item.prices;
        // Todo, check if deleting reference works instead.
        //delete prices;

        PriceStruct[] storage prices = item.prices;

        /**
        Would have been nice to have helper function to do
        this here and in additem, but function parameters have to be
        memeory and memory items don't have the push.
        There maybe a way to get around, to figure out later
         */
        for (uint i = 0; i < prices.length; i++) {
            prices.push(priceArray[i]);
        }
    }

    // Helper getter functions for working with web3
    // getNumItems() is just slightly more convenient.
    // getItem and getPriceStruct are required, since there is not other way to access this data

    function getNumItems() public view returns (uint) {
        if (inventories[msg.sender].available) {
            return inventories[msg.sender].numItems;
        } else {
            return 0; // Zero items if inventory does not exist yet
        }
    }

    function getItem(uint itemId) public view returns (Item memory){
        require(inventories[msg.sender].available, "Inventory not available");
        return inventories[msg.sender].items[itemId];
    }

    function getPriceStruct(uint itemId, uint priceStructIndex) public view returns (PriceStruct memory){
        require(inventories[msg.sender].available, "Inventory not available");
        return inventories[msg.sender].items[itemId].prices[priceStructIndex];
    }


    // ---------- Product registry section --------------

    // Parts can be items or products
    enum PART_TYPE {
        ITEM,
        PRODUCT
    }

    struct Part {
        PART_TYPE partType;
        // If part is item, then manufacturerId is supplier address
        // If part is product, then manufacturerId is designer address
        address manufacturerId;

        //bytes32 hashedDescription;
        // If part is an item, partId should be the item_id in the
        // manufacturer's inventory.
        // If part is a product, partId should be the product_ID
        uint partId;
        uint quantity;
    }

    // This is a way to track all customer bids for each product
    // Not tracking bids in products anymore
    //struct ProductBid {
    //    address customer;
    //    uint bidId;
    //}

    struct Product {
        Part[] partsArray;
        // Bids needs to be another data structure that supports deletion.
        // Singly-linked list would work.
        //ProductBid[] productBids;
        // For now, just going to set customer address to zero for inactive bids
        //uint numBids;
        // Num bids unnecessary, since that is just bids array length
        bool available;
    }

    struct ProductRegistry {
        uint numProducts; // acts as ID
        bool available;
        mapping (uint => Product) products;
    }

    // Designer product registries tied to their owner address
    mapping (address => ProductRegistry) public productRegistries;

    function addProduct(Part[] memory partsArray) public {
        if (!productRegistries[msg.sender].available) {
            productRegistries[msg.sender].available = true;
        }

        ProductRegistry storage registry = productRegistries[msg.sender];
        registry.products[registry.numProducts].available = true;

        Part[] storage newProduct = registry.products[registry.numProducts++].partsArray;

        // Copy partsArray into newProduct
        for (uint i = 0; i < partsArray.length; i++) {
            // Todo, should add checks to ensure the part ID exists for the manufacturer
            newProduct.push(partsArray[i]);
        }
    }

    function removeProduct(uint productId) public {
        require(productRegistries[msg.sender].available, "Product registry not available");

        ProductRegistry storage registry = productRegistries[msg.sender];

        delete registry.products[productId];
        //registry.products[productId].available = false;
    }

    function getNextProductId() public view returns (uint) {
        if (productRegistries[msg.sender].available) {
            return productRegistries[msg.sender].numProducts;
        } else {
            return 0; // Next id will be zero if registry does not exist yet
        }
        // Todo, could likely replace entire body with below due to zero default
        //return productRegistries[msg.sender].numProducts;
    }

    function getPreviousProductId() public view returns (uint) {
        if (productRegistries[msg.sender].available && productRegistries[msg.sender].numProducts != 0) {
            return productRegistries[msg.sender].numProducts - 1;
        } else {
            return ~uint(0); // largest uint
        }
    }

    // Helper getter functions for working with web3
    // getNumProducts() is just slightly more convenient.
    // getProduct, getProductPart, and getProductBid are required,
    // since there is not other way to access this data.

    // This function is identical to getNextProductId
    function getNumProducts() public view returns (uint) {
        if (productRegistries[msg.sender].available) {
            return productRegistries[msg.sender].numProducts;
        } else {
            return 0; // Zero items if product registry does not exist yet
        }
    }

    // This will probably work fine too, since defaults to zero
    //function getNumProducts() public view returns (uint) {
    //    return productRegistries[msg.sender].numProducts;
    //}

    function getProduct(uint productId) public view returns (Product memory) {
        require(productRegistries[msg.sender].available, "Product Registry not available");
        return productRegistries[msg.sender].products[productId];
    }

    function getProductPart(uint productId, uint partIndex) public view returns (Part memory) {
        require(productRegistries[msg.sender].available, "Product Registry not available");
        return productRegistries[msg.sender].products[productId].partsArray[partIndex];
    }

    //function getProductBid(uint productId, uint bidIndex) public view returns (ProductBid memory) {
    //    require(productRegistries[msg.sender].available, "Product Registry not available");
    //    return productRegistries[msg.sender].products[productId].productBids[bidIndex];
    //}

    // ---------- Bids section --------------

    /*
    Each customer has deposited funds, and a way to retrieve their previous bid ID.
    Not wasting storage to protect customers against grabing a non-existing previous bid ID.
    - Will just get zero (potentially valid ID) in that case.
    Could alternatively use events as a way to retrieve the previous bid ID.

    Bids for all customers and products are tracked in shared list.
    This list supports deletion and lookup by bidID.

    May only bid on products, not items.
    Could eliminate quantity field by requiring creation of another product to specify quantity.

    */
    struct Bid {
        address customer;
        // Todo - eventually use shared product registry and eliminate designer
        address designer;
        uint productId;
        uint bidWei; // @ quantity 1, so totalBid = bidWei * quantity
        uint quantity;
        uint bidArrayIndex;
    }

    struct Customer {
        uint fundsWei;
        uint previousBidId; // no error protection against non-existant previousBidId
    }

    // This ensures each bidID is unique
    uint nextBidId;

    mapping (address => Customer) public customers;
    mapping (uint => Bid) public bids;
    uint[] public bidArray;

    function placeBid(address designer, uint productId, uint bidWei, uint quantity) public {
        // Ensure that product is available
        require(productRegistries[designer].available, "Product registry not available for designer");
        ProductRegistry storage registry = productRegistries[designer];
        require(registry.products[productId].available, "Product not available in registry");

        Customer storage customer = customers[msg.sender];
        customer.previousBidId = nextBidId;

        Bid storage bid = bids[nextBidId];
        bid.bidArrayIndex = bidArray.length;
        bidArray.push(nextBidId);

        bid.designer = designer;
        bid.customer = msg.sender;
        bid.productId = productId;
        bid.bidWei = bidWei;
        bid.quantity = quantity;

        nextBidId++;

        // Would be even better to emit events when bids are placed and removed
        // to make it easier for folks to monitor execution conditions without
        // having to re-scan bid list every time.
    }

    function removeBid(uint bidId) public {

        // Note index in array to delete
        uint indexToDelete = bids[bidId].bidArrayIndex;
        // Grab ID at last index
        uint bidIdToFillArrayHole = bidArray[bidArray.length - 1];
        // Overwrite id at deleted index
        bidArray[indexToDelete] = bidIdToFillArrayHole;
        // Make sure struct in mapping points back to array
        bids[bidIdToFillArrayHole].bidArrayIndex = indexToDelete;
        // Remove last array element
        bidArray.length--;

        delete bids[bidId];

        // Todo - This requires more testing
    }

    function getPreviousBidId() public view returns (uint) {
        return customers[msg.sender].previousBidId;
    }

    function depositFunds() public payable {
        // Increment funds
        customers[msg.sender].fundsWei += msg.value;
    }

    function withdrawFunds() public {
        // Transfer all funds
        msg.sender.transfer(customers[msg.sender].fundsWei);
        // Reset balance to zero
        customers[msg.sender].fundsWei = 0;
    }

    function getBid(uint bidId) public view returns (Bid memory) {
        return bids[bidId];
    }

    function getNumBids() public view returns (uint) {
        return bidArray.length;
    }

    struct ItemTallyElement {
        uint quantity;
        // Todo, this requires a refactor to strip out manufacturer
        // Cannot use a single mapping with manufacturer included
        uint itemArrayIndex;
    }

    function tallyProducts(address designer, uint productId, uint quantity,
    mapping (uint => ItemTallyElement) storage itemTally, uint[] memory itemTallyList) private {
        // Ensure that product is available
        ProductRegistry storage registry = productRegistries[designer];
        require(registry.available, "Product registry not available for designer");
        Product storage product = registry.products[productId];
        require(product.available, "Product not available in registry");

        // Iterate over all parts
        for (uint i = 0; i < product.partsArray.length; i++) {
            Part storage part = product.partsArray[i];
            if (part.quantity == 0) {
                // Skip zero quantity parts
                continue;
            }
            if (part.partType == PART_TYPE.PRODUCT) {
                // Recurse into sub product
                tallyProducts(part.manufacturerId, part.partId, part.quantity * quantity, itemTally, itemTallyList);
            } else if (part.partType == PART_TYPE.ITEM) {
                // Base case. Tally items

                // Assuming refactored to manufacturerless unique itemIds

                ItemTallyElement storage itemElement = itemTally[part.partId];
                // Non-zero quantity is a good way to check for whether item needs to be added to array
                if (itemElement.quantity == 0) {
                    itemElement.itemArrayIndex = itemTallyList.length;
                    // Need to troubleshoot: Member "push" is not available in uint256[] memory outside of storage.
                    //itemTallyList.push(part.partId);
                }
                uint quantityConsumed = quantity * part.quantity;
                itemElement.quantity += quantityConsumed;
                // Good place to reduce inventory for consumed items
                Item storage inventoryItem = inventories[designer].items[part.partId];
                require (inventoryItem.quantityAvailable >= quantityConsumed, "Not enough item quantity" );
                inventoryItem.quantityAvailable -= quantityConsumed;
            }
        }
    }

    function execute(uint[] memory bidIdArray, uint weiPerEthReward) public {
        // Total item count tracking by Item ID
        // Seems like memory would be the best place to keep this mapping,
        // but that cannot be done
        // https://ethereum.stackexchange.com/questions/25282/why-conceptually-cant-mappings-be-local-variables
        // Another error to troubleshoot:
        // Uninitialized mapping. Mappings cannot be created dynamically, you have to assign them from a state variable.
        /*
        mapping (uint => ItemTallyElement) storage itemTally;
        uint[] memory itemTallyList;

        // Item count per item per customer by customer ID
        // Actually just track total price here

        //Pass 1
        //    For all bids
        //        Tally item quantities
        //        Both per-item and per-customer-item

        for (uint i = 0; i < bidIdArray.length; i++) {
            Bid storage bid = bids[bidIdArray[i]];
            // recurse into product tree
            tallyProducts(bid.designer, bid.productId, bid.quantity, itemTally, itemTallyList);

            // Todo - Also tally on a per-customer level. Could be done inside of recursive function
        }
        */

        //Pass 2
        //    For all customers
        //        For all customer items
        //            Tally total cost
        //        Require (tally (including reward) >= total customer bid)
        //        Debit customer balance

        //Pass 3
        //    For all items
        //        Tally manufacturer payments
        //        This must be done after pass 1, which determines quantity and price breaks.
        //        Could include this step with pass 2, but that is probably less efficient.

        //Pass 4
        //    For all manufacturers
        //        Transfer payments.
        //        Could also transfer payments in smaller pieces in earlier step, but that is less efficient.
        //        Another option is to treat manufacturers as a customer / user and let them withdraw.

        //Step 5
        //    Transfer reward to executor.
        //    Or just increment their balance, and let them withdraw later.

    }

    /*
    Next Steps:

    Create a helper function to print out data with human-readable account names.
    For example
        Print all bids.
        Print product tree. This might be tough.

    Get metamask setup with human-readable account names that match ganache.

    Make website more meaningful.
    Possible to populate website with web3.js test code? Likely.

    Show visualization of price curve.
    Show visualization of all customer bids - this might be tough.

    Create many more accounts and pseudorandomly place bids.
    Update visualization.

    Deploy on testnet? This may be slow.

    */

    function createHash(string memory data)
    public pure returns (bytes32) {
        return keccak256(abi.encodePacked(data));
    }
}
