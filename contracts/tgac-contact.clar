;; Token-Gated Access Control Contract
;; tgac-contact
; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-RESOURCE-EXISTS (err u101))
(define-constant ERR-RESOURCE-NOT-FOUND (err u102))
(define-constant ERR-TOKEN-NOT-FOUND (err u103))
(define-constant ERR-INSUFFICIENT-TOKENS (err u104))
(define-constant ERR-ACCESS-EXPIRED (err u105))
(define-constant ERR-NO-ACCESS-RIGHTS (err u106))
(define-constant ERR-MAX-USES-REACHED (err u107))
(define-constant ERR-INVALID-TIME-PERIOD (err u108))
(define-constant ERR-INVALID-TIER (err u109))
(define-constant ERR-MEMBER-EXISTS (err u110))

;; Define access tiers
(define-constant ACCESS-TIER-BASIC u1)
(define-constant ACCESS-TIER-PREMIUM u2)
(define-constant ACCESS-TIER-VIP u3)
(define-constant ACCESS-TIER-FOUNDER u4)

;; Contract owner/admin
(define-data-var contract-owner principal tx-sender)

;; Data maps

;; Map of supported token contracts
(define-map supported-tokens
  { token-contract: principal }
  {
    name: (string-ascii 50),
    active: bool,
    min-balance: uint
  }
)

;; Resource definitions - represents content or access-controlled resources
(define-map resources
  { resource-id: (string-ascii 50) }
  {
    name: (string-ascii 100),
    owner: principal,
    token-contract: principal,
    base-token-requirement: uint, ;; Base tokens required for access
    time-based: bool,          ;; If true, access is time-based
    usage-based: bool,         ;; If true, access is usage-based
    tiered-access: bool,       ;; If true, different tiers have different access levels
    active: bool,
    creation-height: uint
  }
)
;; Resource tiers - only used if tiered-access is true
(define-map resource-tiers
  { 
    resource-id: (string-ascii 50),
    tier: uint 
  }
  {
    token-requirement: uint,
    time-period: uint,        ;; In blocks (if time-based)
    max-uses: uint,           ;; Max number of accesses (if usage-based)
    features: (list 10 (string-ascii 50)) ;; List of features unlocked at this tier
  }
)

;; User access rights
(define-map user-access
  { 
    user: principal,
    resource-id: (string-ascii 50)
  }
  {
    access-granted: bool,
    tier: uint,
    grant-height: uint,        ;; Block when access was granted
    expiry-height: uint,       ;; Block when access expires (for time-based)
    uses-remaining: uint,      ;; For usage-based access
    last-access-height: uint   ;; Last time resource was accessed
  }
)

;; Community/group definitions for collective access
(define-map communities
  { community-id: (string-ascii 50) }
  {
    name: (string-ascii 100),
    owner: principal,
    token-contract: principal,
    required-tokens: uint,
    active: bool
  }
)
;; Community membership
(define-map community-members
  {
    community-id: (string-ascii 50),
    member: principal
  }
  {
    join-height: uint,
    active: bool
  }
)

;; Resources shared with communities
(define-map community-resources
  {
    community-id: (string-ascii 50),
    resource-id: (string-ascii 50)
  }
  {
    grant-height: uint,
    active: bool
  }
)

;; Functions for administration

;; Set the contract owner
(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)
  )
)
;; Add a supported token
(define-public (add-supported-token (token-contract principal) (name (string-ascii 50)) (min-balance uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (map-set supported-tokens
      { token-contract: token-contract }
      {
        name: name,
        active: true,
        min-balance: min-balance
      }
    )
    (ok true)
  )
)

;; Update token status
(define-public (update-token-status (token-contract principal) (active bool) (min-balance uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (asserts! (is-some (map-get? supported-tokens { token-contract: token-contract })) ERR-TOKEN-NOT-FOUND)
    
    (let ((token (unwrap-panic (map-get? supported-tokens { token-contract: token-contract }))))
      (map-set supported-tokens
        { token-contract: token-contract }
        {
          name: (get name token),
          active: active,
          min-balance: min-balance
        }
      )
    )
    (ok true)
  )
)
;; Functions for resource management

;; Create a new gated resource
(define-public (create-resource 
                 (resource-id (string-ascii 50)) 
                 (name (string-ascii 100))
                 (token-contract principal)
                 (base-token-requirement uint)
                 (time-based bool)
                 (usage-based bool)
                 (tiered-access bool))
  (begin
    ;; Check if token is supported
    (asserts! (is-some (map-get? supported-tokens { token-contract: token-contract })) ERR-TOKEN-NOT-FOUND)
    ;; Check that resource doesn't already exist
    (asserts! (is-none (map-get? resources { resource-id: resource-id })) ERR-RESOURCE-EXISTS)
    
    ;; Create resource
    (map-set resources
      { resource-id: resource-id }
      {
        name: name,
        owner: tx-sender,
        token-contract: token-contract,
        base-token-requirement: base-token-requirement,
        time-based: time-based,
        usage-based: usage-based,
        tiered-access: tiered-access,
        active: true,
        creation-height: block-height
      }
    )
    
    ;; If not using tiers, create the default tier
    (if (not tiered-access)
        (map-set resource-tiers
          { 
            resource-id: resource-id,