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