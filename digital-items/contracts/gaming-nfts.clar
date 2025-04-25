;; Realm Legends Digital Asset Management
;; A comprehensive smart contract for managing in-game digital assets including:
;; - NFT creation and ownership
;; - Secure asset transfers between players
;; - Marketplace functionality for buying and selling game items
;; - Character progression tracking

;; CONSTANTS

;; Administrative Constants
(define-constant contract-admin tx-sender)

;; Error Constants
(define-constant ERR-ADMIN-ONLY (err u100))
(define-constant ERR-ASSET-NOT-FOUND (err u101))
(define-constant ERR-UNAUTHORIZED-ACCESS (err u102))
(define-constant ERR-INVALID-PARAMETERS (err u103))
(define-constant ERR-INVALID-LISTING-PRICE (err u104))

;; Game Mechanic Limits
(define-constant MAX-PLAYER-LEVEL u100)
(define-constant MAX-PLAYER-EXPERIENCE u10000)
(define-constant MAX-ASSET-METADATA-LENGTH u256)
(define-constant MAX-BATCH-SIZE u10)  ;; Limit batch operations to prevent potential gas issues

;; DATA STRUCTURES
;; Game Assets Registry
(define-map digital-assets 
    { asset-id: uint }
    { asset-owner: principal, metadata-uri: (string-utf8 256), is-transferable: bool })

;; Marketplace Listings
(define-map marketplace-listings
    { asset-id: uint }
    { asset-seller: principal, listing-price: uint, listing-timestamp: uint })

;; Player Progression System
(define-map player-stats
    { player-address: principal }
    { player-experience: uint, player-level: uint })

;; Asset Counter
(define-data-var total-assets-created uint u0)

;; HELPER FUNCTIONS
;; Validate asset exists and return asset data
(define-private (get-validated-asset (asset-id uint))
    (let ((asset-data (map-get? digital-assets { asset-id: asset-id })))
        (asserts! (and 
                (is-some asset-data)
                (<= asset-id (var-get total-assets-created)))
            ERR-ASSET-NOT-FOUND)
        (ok (unwrap-panic asset-data))))

;; Validate metadata URI length
(define-private (is-valid-metadata-uri (uri (string-utf8 256)))
    (let ((uri-length (len uri)))
        (and 
            (> uri-length u0)
            (<= uri-length MAX-ASSET-METADATA-LENGTH))))

;; ASSET CREATION FUNCTIONS

;; Create multiple game assets in a single transaction
(define-public (batch-create-assets 
    (metadata-uri-list (list 10 (string-utf8 256))) 
    (transferability-list (list 10 bool)))
    (begin
        (asserts! (is-eq tx-sender contract-admin) ERR-ADMIN-ONLY)
        (asserts! (and 
            (> (len metadata-uri-list) u0)
            (<= (len metadata-uri-list) MAX-BATCH-SIZE)
            (is-eq (len metadata-uri-list) (len transferability-list))) 
            ERR-INVALID-PARAMETERS)
        (let ((created-asset-ids 
            (map create-single-asset 
                metadata-uri-list 
                transferability-list)))
            (ok created-asset-ids))))

;; Helper function for batch asset creation
(define-private (create-single-asset 
    (metadata-uri (string-utf8 256))
    (is-transferable bool))
    (let 
        ((new-asset-id (+ (var-get total-assets-created) u1)))
        (asserts! (is-valid-metadata-uri metadata-uri) ERR-INVALID-PARAMETERS)
        (map-set digital-assets
            { asset-id: new-asset-id }
            { asset-owner: contract-admin,
              metadata-uri: metadata-uri,
              is-transferable: is-transferable })
        (var-set total-assets-created new-asset-id)
        (ok new-asset-id)))

;; Create a single game asset
(define-public (create-asset (metadata-uri (string-utf8 256)) (is-transferable bool))
    (let
        ((new-asset-id (+ (var-get total-assets-created) u1)))
        (asserts! (is-eq tx-sender contract-admin) ERR-ADMIN-ONLY)
        (asserts! (is-valid-metadata-uri metadata-uri) ERR-INVALID-PARAMETERS)
        (map-set digital-assets
            { asset-id: new-asset-id }
            { asset-owner: tx-sender,
              metadata-uri: metadata-uri,
              is-transferable: is-transferable })
        (var-set total-assets-created new-asset-id)
        (ok new-asset-id)))

;; ASSET TRANSFER FUNCTIONS
;; Transfer multiple assets in a batch operation
(define-public (batch-transfer-assets 
    (asset-id-list (list 10 uint)) 
    (recipient-list (list 10 principal)))
    (begin
        (asserts! (and 
            (> (len asset-id-list) u0)
            (<= (len asset-id-list) MAX-BATCH-SIZE)
            (is-eq (len asset-id-list) (len recipient-list))) 
            ERR-INVALID-PARAMETERS)
        (let ((transfer-results 
            (map transfer-single-asset 
                asset-id-list 
                recipient-list)))
            (ok transfer-results))))

;; Helper function for batch transfers
(define-private (transfer-single-asset 
    (asset-id uint)
    (recipient principal))
    (let 
        ((asset-data (unwrap-panic (get-validated-asset asset-id))))
        (asserts! (and
                (is-eq (get asset-owner asset-data) tx-sender)
                (get is-transferable asset-data)
                (not (is-eq recipient tx-sender)))  ;; Prevent self-transfers
            ERR-UNAUTHORIZED-ACCESS)
        (map-set digital-assets
            { asset-id: asset-id }
            { asset-owner: recipient,
              metadata-uri: (get metadata-uri asset-data),
              is-transferable: (get is-transferable asset-data) })
        (ok true)))

;; Transfer a single asset to another player
(define-public (transfer-asset (asset-id uint) (recipient principal))
    (begin
        (asserts! (<= asset-id (var-get total-assets-created)) ERR-INVALID-PARAMETERS)
        (let ((asset-data (try! (get-validated-asset asset-id))))
            (asserts! (and
                    (is-eq (get asset-owner asset-data) tx-sender)
                    (get is-transferable asset-data)
                    (not (is-eq recipient tx-sender)))  ;; Prevent self-transfers
                ERR-UNAUTHORIZED-ACCESS)
            (map-set digital-assets
                { asset-id: asset-id }
                { asset-owner: recipient,
                  metadata-uri: (get metadata-uri asset-data),
                  is-transferable: (get is-transferable asset-data) })
            (ok true))))

;; MARKETPLACE FUNCTIONS
;; List an asset for sale on the marketplace
(define-public (create-marketplace-listing (asset-id uint) (listing-price uint))
    (begin
        (asserts! (<= asset-id (var-get total-assets-created)) ERR-INVALID-PARAMETERS)
        (let ((asset-data (try! (get-validated-asset asset-id))))
            (asserts! (and 
                    (is-eq (get asset-owner asset-data) tx-sender)
                    (> listing-price u0)
                    (get is-transferable asset-data))  ;; Ensure asset is transferable
                ERR-INVALID-LISTING-PRICE)
            (map-set marketplace-listings
                { asset-id: asset-id }
                { asset-seller: tx-sender, 
                  listing-price: listing-price, 
                  listing-timestamp: block-height })
            (ok true))))

;; Purchase a listed asset from the marketplace
(define-public (purchase-listed-asset (asset-id uint))
    (begin
        (asserts! (<= asset-id (var-get total-assets-created)) ERR-INVALID-PARAMETERS)
        (let
            ((asset-data (try! (get-validated-asset asset-id)))
             (marketplace-data (unwrap! (map-get? marketplace-listings { asset-id: asset-id }) ERR-ASSET-NOT-FOUND)))
            (asserts! (and
                    (not (is-eq (get asset-seller marketplace-data) tx-sender))
                    (get is-transferable asset-data))
                ERR-UNAUTHORIZED-ACCESS)
            (try! (stx-transfer? (get listing-price marketplace-data) tx-sender (get asset-seller marketplace-data)))
            (map-set digital-assets
                { asset-id: asset-id }
                { asset-owner: tx-sender,
                  metadata-uri: (get metadata-uri asset-data),
                  is-transferable: (get is-transferable asset-data) })
            (map-delete marketplace-listings { asset-id: asset-id })
            (ok true))))

;; Remove an asset listing from the marketplace
(define-public (remove-marketplace-listing (asset-id uint))
    (begin
        ;; Validate asset-id is within range
        (asserts! (<= asset-id (var-get total-assets-created)) ERR-INVALID-PARAMETERS)
        
        ;; Get listing data, return error if not found
        (let ((marketplace-data (unwrap! (map-get? marketplace-listings { asset-id: asset-id }) ERR-ASSET-NOT-FOUND)))
            ;; Ensure only the seller can remove listing
            (asserts! (is-eq tx-sender (get asset-seller marketplace-data)) ERR-UNAUTHORIZED-ACCESS)
            
            ;; Delete the marketplace listing
            (map-delete marketplace-listings { asset-id: asset-id })
            
            ;; Return success
            (ok true))))

;; PLAYER PROGRESSION FUNCTIONS
;; Update player's experience and level
(define-public (update-player-progression (new-experience uint) (new-level uint))
    (begin
        (asserts! (<= new-experience MAX-PLAYER-EXPERIENCE) ERR-INVALID-PARAMETERS)
        (asserts! (<= new-level MAX-PLAYER-LEVEL) ERR-INVALID-PARAMETERS)
        (map-set player-stats
            { player-address: tx-sender }
            { player-experience: new-experience, player-level: new-level })
        (ok true)))

;; READ-ONLY FUNCTIONS
;; Get asset details
(define-read-only (get-asset-details (asset-id uint))
    (if (<= asset-id (var-get total-assets-created))
        (map-get? digital-assets { asset-id: asset-id })
        none))

;; Get marketplace listing information
(define-read-only (get-listing-details (asset-id uint))
    (map-get? marketplace-listings { asset-id: asset-id }))

;; Get player progression information
(define-read-only (get-player-stats (player-address principal))
    (map-get? player-stats { player-address: player-address }))

;; Get total number of assets created
(define-read-only (get-total-assets)
    (var-get total-assets-created))