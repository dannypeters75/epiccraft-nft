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
(define-constant ERR-ASSET-NOT-TRANSFERABLE (err u105))
(define-constant ERR-SELLER-NOT-OWNER (err u106))
(define-constant ERR-INVALID-LEVEL-FOR-EXPERIENCE (err u107))
(define-constant ERR-TRANSFER-TO-SELF (err u108))
(define-constant ERR-INDEX-OUT-OF-BOUNDS (err u109))

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

;; EVENTS
;; Asset Transfer Event
(define-data-var last-event-asset-id uint u0)
(define-data-var last-event-timestamp uint u0)
(define-map transfer-events
    { event-id: uint }
    { asset-id: uint, from: principal, to: principal, timestamp: uint })

;; Marketplace Events
(define-map marketplace-events
    { event-id: uint }
    { event-type: (string-ascii 32), asset-id: uint, price: uint, user: principal, timestamp: uint })

;; Event Counter
(define-data-var total-events uint u0)

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

;; Event logging function
(define-private (log-event (event-type (string-ascii 32)) (asset-id uint) (price uint) (user principal))
    (let ((event-id (+ (var-get total-events) u1)))
        (map-set marketplace-events
            { event-id: event-id }
            { event-type: event-type, 
              asset-id: asset-id, 
              price: price, 
              user: user, 
              timestamp: block-height })
        (var-set total-events event-id)
        event-id))

;; Log transfer event
(define-private (log-transfer-event (asset-id uint) (from principal) (to principal))
    (let ((event-id (+ (var-get total-events) u1)))
        (map-set transfer-events
            { event-id: event-id }
            { asset-id: asset-id, 
              from: from, 
              to: to, 
              timestamp: block-height })
        (var-set total-events event-id)
        (var-set last-event-asset-id asset-id)
        (var-set last-event-timestamp block-height)
        event-id))

;; Check if level is valid for the given experience
(define-private (is-valid-level-for-experience (experience uint) (level uint))
    ;; Simple validation: each level requires (level * 100) experience points
    ;; This would be replaced with a more sophisticated game mechanic in practice
    (and 
        (<= level MAX-PLAYER-LEVEL)
        (<= experience MAX-PLAYER-EXPERIENCE)
        (>= experience (* level u100))))

;; List element access with boundary checking
(define-private (safe-get-at (index uint) (lst (list 10 (string-utf8 256))))
    (let ((length (len lst)))
        (if (< index length)
            (ok (unwrap-panic (element-at lst index)))
            ERR-INDEX-OUT-OF-BOUNDS)))

;; List element access with boundary checking for booleans
(define-private (safe-get-bool-at (index uint) (lst (list 10 bool)))
    (let ((length (len lst)))
        (if (< index length)
            (ok (unwrap-panic (element-at lst index)))
            ERR-INDEX-OUT-OF-BOUNDS)))

;; List element access with boundary checking for uints
(define-private (safe-get-uint-at (index uint) (lst (list 10 uint)))
    (let ((length (len lst)))
        (if (< index length)
            (ok (unwrap-panic (element-at lst index)))
            ERR-INDEX-OUT-OF-BOUNDS)))

;; List element access with boundary checking for principals
(define-private (safe-get-principal-at (index uint) (lst (list 10 principal)))
    (let ((length (len lst)))
        (if (< index length)
            (ok (unwrap-panic (element-at lst index)))
            ERR-INDEX-OUT-OF-BOUNDS)))

;; ASSET CREATION FUNCTIONS
;; Helper function for creating a single asset
(define-private (create-single-asset 
    (metadata-uri (string-utf8 256))
    (is-transferable bool))
    (let 
        ((new-asset-id (+ (var-get total-assets-created) u1)))
        
        ;; Validate metadata URI
        (asserts! (is-valid-metadata-uri metadata-uri) ERR-INVALID-PARAMETERS)
        
        ;; Set the asset data
        (map-set digital-assets
            { asset-id: new-asset-id }
            { asset-owner: contract-admin,
              metadata-uri: metadata-uri,
              is-transferable: is-transferable })
        
        ;; Update the total assets counter
        (var-set total-assets-created new-asset-id)
        
        ;; Log the creation event
        (log-event "asset-created" new-asset-id u0 contract-admin)
        
        (ok new-asset-id)))

;; Process single item in batch creation
(define-private (process-create-item (index uint) (metadata-list (list 10 (string-utf8 256))) (transferability-list (list 10 bool)))
    (let ((metadata-result (safe-get-at index metadata-list))
          (transferable-result (safe-get-bool-at index transferability-list)))
          
        (match metadata-result
            metadata-uri 
            (match transferable-result
                is-transferable (create-single-asset metadata-uri is-transferable)
                error ERR-INVALID-PARAMETERS)
            error ERR-INVALID-PARAMETERS)))

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
        
        ;; Process batch creation without recursion
        (let ((batch-size (len metadata-uri-list)))
            (if (> batch-size u0)
                (let ((result-0 (process-create-item u0 metadata-uri-list transferability-list))
                      (asset-ids (list)))
                    (if (is-ok result-0)
                        (let ((asset-ids-1 (append asset-ids (unwrap-panic result-0))))
                            (if (> batch-size u1)
                                (let ((result-1 (process-create-item u1 metadata-uri-list transferability-list)))
                                    (if (is-ok result-1)
                                        (let ((asset-ids-2 (append asset-ids-1 (unwrap-panic result-1))))
                                            (if (> batch-size u2)
                                                (let ((result-2 (process-create-item u2 metadata-uri-list transferability-list)))
                                                    (if (is-ok result-2)
                                                        (ok (append asset-ids-2 (unwrap-panic result-2)))
                                                        (ok asset-ids-2)))
                                                (ok asset-ids-2)))
                                        (ok asset-ids-1)))
                                (ok asset-ids-1)))
                        (ok asset-ids)))
                (ok (list))))))

;; Create a single game asset
(define-public (create-asset (metadata-uri (string-utf8 256)) (is-transferable bool))
    (begin
        (asserts! (is-eq tx-sender contract-admin) ERR-ADMIN-ONLY)
        ;; Validate metadata URI before passing to create-single-asset
        (asserts! (is-valid-metadata-uri metadata-uri) ERR-INVALID-PARAMETERS)
        (try! (create-single-asset metadata-uri is-transferable))
        (ok (var-get total-assets-created))))

;; ASSET TRANSFER FUNCTIONS
;; Helper function for transferring a single asset
(define-private (transfer-single-asset 
    (asset-id uint)
    (recipient principal))
    (let 
        ((asset-data-response (get-validated-asset asset-id)))
        
        (match asset-data-response
            asset-data
            (begin
                ;; Validate ownership and transferability
                (asserts! (is-eq (get asset-owner asset-data) tx-sender) ERR-UNAUTHORIZED-ACCESS)
                (asserts! (get is-transferable asset-data) ERR-ASSET-NOT-TRANSFERABLE)
                (asserts! (not (is-eq recipient tx-sender)) ERR-TRANSFER-TO-SELF)
                
                ;; Update asset ownership
                (map-set digital-assets
                    { asset-id: asset-id }
                    { asset-owner: recipient,
                      metadata-uri: (get metadata-uri asset-data),
                      is-transferable: (get is-transferable asset-data) })
                
                ;; Remove any marketplace listing for this asset
                (map-delete marketplace-listings { asset-id: asset-id })
                
                ;; Log the transfer event
                (log-transfer-event asset-id tx-sender recipient)
                
                (ok true))
            
            error-code (err error-code))))

;; Process single item in batch transfer
(define-private (process-transfer-item (index uint) (asset-list (list 10 uint)) (recipient-list (list 10 principal)))
    (let ((asset-id-result (safe-get-uint-at index asset-list))
          (recipient-result (safe-get-principal-at index recipient-list)))
          
        (match asset-id-result
            asset-id 
            (match recipient-result
                recipient (transfer-single-asset asset-id recipient)
                error ERR-INVALID-PARAMETERS)
            error ERR-INVALID-PARAMETERS)))

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
        
        ;; Process batch transfers without recursion
        (let ((batch-size (len asset-id-list)))
            (if (> batch-size u0)
                (let ((result-0 (process-transfer-item u0 asset-id-list recipient-list))
                      (results (list)))
                    (let ((results-1 (append results (if (is-ok result-0) true false))))
                        (if (> batch-size u1)
                            (let ((result-1 (process-transfer-item u1 asset-id-list recipient-list)))
                                (let ((results-2 (append results-1 (if (is-ok result-1) true false))))
                                    (if (> batch-size u2)
                                        (let ((result-2 (process-transfer-item u2 asset-id-list recipient-list)))
                                            (let ((results-3 (append results-2 (if (is-ok result-2) true false))))
                                                (ok results-3)))
                                        (ok results-2))))
                            (ok results-1))))
                (ok (list))))))

;; Transfer a single asset to another player
(define-public (transfer-asset (asset-id uint) (recipient principal))
    (begin
        ;; Validate asset ID and recipient before passing to transfer-single-asset
        (asserts! (<= asset-id (var-get total-assets-created)) ERR-INVALID-PARAMETERS)
        (asserts! (not (is-eq recipient tx-sender)) ERR-TRANSFER-TO-SELF)
        
        ;; Additional validation of the asset's existence
        (let ((asset-data (map-get? digital-assets { asset-id: asset-id })))
            (asserts! (is-some asset-data) ERR-ASSET-NOT-FOUND)
            (transfer-single-asset asset-id recipient))))

;; MARKETPLACE FUNCTIONS
;; List an asset for sale on the marketplace
(define-public (create-marketplace-listing (asset-id uint) (listing-price uint))
    (begin
        (asserts! (<= asset-id (var-get total-assets-created)) ERR-INVALID-PARAMETERS)
        (asserts! (> listing-price u0) ERR-INVALID-LISTING-PRICE)
        
        (let ((asset-data (try! (get-validated-asset asset-id))))
            ;; Validate ownership and transferability
            (asserts! (is-eq (get asset-owner asset-data) tx-sender) ERR-UNAUTHORIZED-ACCESS)
            (asserts! (get is-transferable asset-data) ERR-ASSET-NOT-TRANSFERABLE)
            
            ;; Create the listing
            (map-set marketplace-listings
                { asset-id: asset-id }
                { asset-seller: tx-sender, 
                  listing-price: listing-price, 
                  listing-timestamp: block-height })
            
            ;; Log the event
            (log-event "listing-created" asset-id listing-price tx-sender)
            
            (ok true))))

;; Purchase a listed asset from the marketplace
(define-public (purchase-listed-asset (asset-id uint))
    (begin
        (asserts! (<= asset-id (var-get total-assets-created)) ERR-INVALID-PARAMETERS)
        
        (let
            ((asset-data (try! (get-validated-asset asset-id)))
             (marketplace-data (unwrap! (map-get? marketplace-listings { asset-id: asset-id }) ERR-ASSET-NOT-FOUND)))
            
            ;; Validate seller is still the owner
            (asserts! (is-eq (get asset-seller marketplace-data) (get asset-owner asset-data)) 
                ERR-SELLER-NOT-OWNER)
            
            ;; Validate buyer is not seller
            (asserts! (not (is-eq (get asset-seller marketplace-data) tx-sender)) 
                ERR-UNAUTHORIZED-ACCESS)
            
            ;; Validate asset is transferable
            (asserts! (get is-transferable asset-data) 
                ERR-ASSET-NOT-TRANSFERABLE)
            
            ;; Process payment first (state changes after transfers)
            (try! (stx-transfer? (get listing-price marketplace-data) tx-sender (get asset-seller marketplace-data)))
            
            ;; Update asset ownership
            (map-set digital-assets
                { asset-id: asset-id }
                { asset-owner: tx-sender,
                  metadata-uri: (get metadata-uri asset-data),
                  is-transferable: (get is-transferable asset-data) })
            
            ;; Remove the listing
            (map-delete marketplace-listings { asset-id: asset-id })
            
            ;; Log the purchase event
            (log-event "asset-purchased" asset-id (get listing-price marketplace-data) tx-sender)
            (log-transfer-event asset-id (get asset-seller marketplace-data) tx-sender)
            
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
            
            ;; Log the event
            (log-event "listing-removed" asset-id (get listing-price marketplace-data) tx-sender)
            
            ;; Return success
            (ok true))))

;; PLAYER PROGRESSION FUNCTIONS
;; Update player's experience and level
(define-public (update-player-progression (new-experience uint) (new-level uint))
    (begin
        ;; Validate experience and level caps
        (asserts! (<= new-experience MAX-PLAYER-EXPERIENCE) ERR-INVALID-PARAMETERS)
        (asserts! (<= new-level MAX-PLAYER-LEVEL) ERR-INVALID-PARAMETERS)
        
        ;; Validate level is appropriate for experience
        (asserts! (is-valid-level-for-experience new-experience new-level) 
            ERR-INVALID-LEVEL-FOR-EXPERIENCE)
        
        ;; Update player stats
        (map-set player-stats
            { player-address: tx-sender }
            { player-experience: new-experience, player-level: new-level })
        
        ;; Log the progression event
        (log-event "player-progression" u0 new-experience tx-sender)
        
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

;; Get transfer event details by event ID
(define-read-only (get-transfer-event (event-id uint))
    (map-get? transfer-events { event-id: event-id }))

;; Get marketplace event details by event ID
(define-read-only (get-marketplace-event (event-id uint))
    (map-get? marketplace-events { event-id: event-id }))

;; Get total number of events
(define-read-only (get-total-events)
    (var-get total-events))

;; Get last transfer event details
(define-read-only (get-last-transfer-event)
    (tuple 
        (asset-id (var-get last-event-asset-id))
        (timestamp (var-get last-event-timestamp))))