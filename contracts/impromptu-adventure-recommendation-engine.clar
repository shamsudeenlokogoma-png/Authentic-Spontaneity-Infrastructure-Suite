;; Impromptu Adventure Recommendation Engine
;; Uses behavioral analysis to suggest perfectly timed spontaneous activities that feel organic

;; Define constants for activity types and behavior analysis
(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-USER-NOT-FOUND (err u404))
(define-constant ERR-INVALID-ACTIVITY (err u400))
(define-constant ERR-INSUFFICIENT-DATA (err u402))
(define-constant ERR-TIMING-CONFLICT (err u403))
(define-constant ERR-LOW-SPONTANEITY-SCORE (err u405))

;; Activity type constants
(define-constant ACTIVITY-TYPE-OUTDOOR u1)
(define-constant ACTIVITY-TYPE-SOCIAL u2)
(define-constant ACTIVITY-TYPE-CREATIVE u3)
(define-constant ACTIVITY-TYPE-RELAXATION u4)
(define-constant ACTIVITY-TYPE-ADVENTURE u5)
(define-constant ACTIVITY-TYPE-LEARNING u6)

;; Behavior analysis constants
(define-constant MIN-DATA-POINTS u10)
(define-constant MIN-SPONTANEITY-SCORE u50)
(define-constant MAX-SPONTANEITY-SCORE u100)
(define-constant RECOMMENDATION-COOLDOWN u86400) ;; 24 hours in seconds

;; Data structures
(define-map user-profiles principal {
    registration-time: uint,
    total-activities: uint,
    spontaneity-score: uint,
    preferred-activity-types: (list 6 uint),
    behavior-patterns: (list 10 uint),
    last-recommendation-time: uint,
    activity-success-rate: uint,
    risk-tolerance: uint
})

(define-map user-behavior-data (tuple (user principal) (timestamp uint)) {
    activity-type: uint,
    duration: uint,
    satisfaction-score: uint,
    time-of-day: uint,
    day-of-week: uint,
    weather-condition: uint,
    social-context: uint
})

(define-map activity-templates uint {
    name: (string-ascii 50),
    description: (string-ascii 200),
    activity-type: uint,
    duration-estimate: uint,
    required-spontaneity-level: uint,
    complexity-score: uint,
    social-requirement: uint,
    weather-dependency: uint
})

(define-map recommendation-history (tuple (user principal) (recommendation-id uint)) {
    timestamp: uint,
    activity-template-id: uint,
    predicted-satisfaction: uint,
    actual-satisfaction: (optional uint),
    completion-status: bool,
    contextual-factors: (list 5 uint)
})

;; Activity counter for unique IDs
(define-data-var activity-counter uint u0)
(define-data-var recommendation-counter uint u0)

;; Contract owner
(define-data-var contract-owner principal tx-sender)

;; User registration and profile management
(define-public (register-user (preferred-types (list 6 uint)) (risk-tolerance uint))
    (let (
        (current-time (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
    )
        (asserts! (is-none (map-get? user-profiles tx-sender)) ERR-NOT-AUTHORIZED)
        (asserts! (<= risk-tolerance u100) ERR-INVALID-ACTIVITY)
        (map-set user-profiles tx-sender {
            registration-time: current-time,
            total-activities: u0,
            spontaneity-score: u50, ;; Starting score
            preferred-activity-types: preferred-types,
            behavior-patterns: (list),
            last-recommendation-time: u0,
            activity-success-rate: u50,
            risk-tolerance: risk-tolerance
        })
        (ok true)
    )
)

;; Update user behavior data
(define-public (record-activity-data 
    (activity-type uint) 
    (duration uint) 
    (satisfaction-score uint)
    (time-of-day uint)
    (day-of-week uint)
    (weather-condition uint)
    (social-context uint)
)
    (let (
        (current-time (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
        (user-profile (unwrap! (map-get? user-profiles tx-sender) ERR-USER-NOT-FOUND))
    )
        (asserts! (<= satisfaction-score u100) ERR-INVALID-ACTIVITY)
        (asserts! (<= activity-type u6) ERR-INVALID-ACTIVITY)
        (asserts! (<= time-of-day u24) ERR-INVALID-ACTIVITY)
        (asserts! (<= day-of-week u7) ERR-INVALID-ACTIVITY)
        
        ;; Record behavior data
        (map-set user-behavior-data 
            { user: tx-sender, timestamp: current-time }
            {
                activity-type: activity-type,
                duration: duration,
                satisfaction-score: satisfaction-score,
                time-of-day: time-of-day,
                day-of-week: day-of-week,
                weather-condition: weather-condition,
                social-context: social-context
            }
        )
        
        ;; Update user profile
        (map-set user-profiles tx-sender 
            (merge user-profile {
                total-activities: (+ (get total-activities user-profile) u1),
                spontaneity-score: (calculate-new-spontaneity-score 
                    (get spontaneity-score user-profile) 
                    satisfaction-score
                    activity-type
                )
            })
        )
        (ok true)
    )
)

;; Calculate spontaneity score based on activity satisfaction and type
(define-private (calculate-new-spontaneity-score (current-score uint) (satisfaction uint) (activity-type uint))
    (let (
        (base-adjustment (if (> satisfaction u70) u5 u0))
        (penalty (if (<= satisfaction u70) u3 u0))
        (type-bonus (if (or (is-eq activity-type ACTIVITY-TYPE-ADVENTURE) 
                           (is-eq activity-type ACTIVITY-TYPE-CREATIVE)) u2 u0))
        (adjusted-score (+ current-score base-adjustment type-bonus))
        (new-score (if (> adjusted-score penalty) (- adjusted-score penalty) u0))
    )
        (if (> new-score MAX-SPONTANEITY-SCORE)
            MAX-SPONTANEITY-SCORE
            new-score
        )
    )
)

;; Generate activity recommendation
(define-public (get-activity-recommendation (current-context (list 5 uint)))
    (let (
        (user-profile (unwrap! (map-get? user-profiles tx-sender) ERR-USER-NOT-FOUND))
        (current-time (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
        (last-rec-time (get last-recommendation-time user-profile))
        (recommendation-id (var-get recommendation-counter))
    )
        ;; Check if enough time has passed since last recommendation
        (asserts! (> (- current-time last-rec-time) RECOMMENDATION-COOLDOWN) ERR-TIMING-CONFLICT)
        
        ;; Check if user has sufficient data and spontaneity score
        (asserts! (>= (get total-activities user-profile) MIN-DATA-POINTS) ERR-INSUFFICIENT-DATA)
        (asserts! (>= (get spontaneity-score user-profile) MIN-SPONTANEITY-SCORE) ERR-LOW-SPONTANEITY-SCORE)
        
        (let (
            (activity-template-id (analyze-and-select-activity user-profile current-context))
            (predicted-satisfaction (calculate-predicted-satisfaction user-profile activity-template-id current-context))
        )
            ;; Record recommendation
            (map-set recommendation-history
                { user: tx-sender, recommendation-id: recommendation-id }
                {
                    timestamp: current-time,
                    activity-template-id: activity-template-id,
                    predicted-satisfaction: predicted-satisfaction,
                    actual-satisfaction: none,
                    completion-status: false,
                    contextual-factors: current-context
                }
            )
            
            ;; Update user profile with new recommendation time
            (map-set user-profiles tx-sender
                (merge user-profile { last-recommendation-time: current-time })
            )
            
            ;; Increment recommendation counter
            (var-set recommendation-counter (+ recommendation-id u1))
            
            (ok { 
                recommendation-id: recommendation-id,
                activity-template-id: activity-template-id,
                predicted-satisfaction: predicted-satisfaction,
                timing-score: (calculate-timing-score current-context),
                spontaneity-boost: (get-spontaneity-boost user-profile activity-template-id)
            })
        )
    )
)

;; Analyze user behavior and select optimal activity
(define-private (analyze-and-select-activity (user-profile (tuple (registration-time uint) (total-activities uint) (spontaneity-score uint) (preferred-activity-types (list 6 uint)) (behavior-patterns (list 10 uint)) (last-recommendation-time uint) (activity-success-rate uint) (risk-tolerance uint))) (context (list 5 uint)))
    (let (
        (preferred-types (get preferred-activity-types user-profile))
        (spontaneity-level (get spontaneity-score user-profile))
        (risk-level (get risk-tolerance user-profile))
    )
        ;; Simple selection algorithm based on preferences and context
        (if (>= spontaneity-level u80)
            (if (>= risk-level u70) u5 u3) ;; High spontaneity: adventure or creative
            (if (>= spontaneity-level u60)
                (if (>= risk-level u50) u2 u4) ;; Medium spontaneity: social or relaxation
                u6 ;; Low spontaneity: learning
            )
        )
    )
)

;; Calculate predicted satisfaction based on user history and activity match
(define-private (calculate-predicted-satisfaction (user-profile (tuple (registration-time uint) (total-activities uint) (spontaneity-score uint) (preferred-activity-types (list 6 uint)) (behavior-patterns (list 10 uint)) (last-recommendation-time uint) (activity-success-rate uint) (risk-tolerance uint))) (activity-id uint) (context (list 5 uint)))
    (let (
        (base-satisfaction (get activity-success-rate user-profile))
        (spontaneity-bonus (/ (get spontaneity-score user-profile) u2))
        (context-adjustment (calculate-context-bonus context))
        (total-score (+ base-satisfaction spontaneity-bonus context-adjustment))
    )
        (if (> total-score u100) u100 total-score)
    )
)

;; Calculate timing score based on contextual factors
(define-private (calculate-timing-score (context (list 5 uint)))
    (let (
        (weather-factor (unwrap-panic (element-at context u0)))
        (energy-level (unwrap-panic (element-at context u1)))
        (social-availability (unwrap-panic (element-at context u2)))
        (time-availability (unwrap-panic (element-at context u3)))
        (mood-state (unwrap-panic (element-at context u4)))
    )
        (/ (+ weather-factor energy-level social-availability time-availability mood-state) u5)
    )
)

;; Calculate context bonus for satisfaction prediction
(define-private (calculate-context-bonus (context (list 5 uint)))
    (let (
        (average-context (/ (fold + context u0) u5))
    )
        (if (>= average-context u70) u10 
            (if (>= average-context u50) u5 u0)
        )
    )
)

;; Get spontaneity boost for activity
(define-private (get-spontaneity-boost (user-profile (tuple (registration-time uint) (total-activities uint) (spontaneity-score uint) (preferred-activity-types (list 6 uint)) (behavior-patterns (list 10 uint)) (last-recommendation-time uint) (activity-success-rate uint) (risk-tolerance uint))) (activity-id uint))
    (let (
        (current-score (get spontaneity-score user-profile))
    )
        (if (is-eq activity-id ACTIVITY-TYPE-ADVENTURE) u15
            (if (is-eq activity-id ACTIVITY-TYPE-CREATIVE) u10
                (if (is-eq activity-id ACTIVITY-TYPE-SOCIAL) u8 u5)
            )
        )
    )
)

;; Update recommendation outcome
(define-public (update-recommendation-outcome (recommendation-id uint) (actual-satisfaction uint) (completed bool))
    (let (
        (recommendation-key { user: tx-sender, recommendation-id: recommendation-id })
        (recommendation-data (unwrap! (map-get? recommendation-history recommendation-key) ERR-USER-NOT-FOUND))
    )
        (asserts! (<= actual-satisfaction u100) ERR-INVALID-ACTIVITY)
        (map-set recommendation-history recommendation-key
            (merge recommendation-data {
                actual-satisfaction: (some actual-satisfaction),
                completion-status: completed
            })
        )
        (ok true)
    )
)

;; Add activity template (admin function)
(define-public (add-activity-template 
    (name (string-ascii 50))
    (description (string-ascii 200))
    (activity-type uint)
    (duration-estimate uint)
    (required-spontaneity-level uint)
    (complexity-score uint)
    (social-requirement uint)
    (weather-dependency uint)
)
    (let (
        (template-id (var-get activity-counter))
    )
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (map-set activity-templates template-id {
            name: name,
            description: description,
            activity-type: activity-type,
            duration-estimate: duration-estimate,
            required-spontaneity-level: required-spontaneity-level,
            complexity-score: complexity-score,
            social-requirement: social-requirement,
            weather-dependency: weather-dependency
        })
        (var-set activity-counter (+ template-id u1))
        (ok template-id)
    )
)

;; Read-only functions
(define-read-only (get-user-profile (user principal))
    (map-get? user-profiles user)
)

(define-read-only (get-user-spontaneity-score (user principal))
    (match (map-get? user-profiles user)
        profile (ok (get spontaneity-score profile))
        ERR-USER-NOT-FOUND
    )
)

(define-read-only (get-activity-template (template-id uint))
    (map-get? activity-templates template-id)
)

(define-read-only (get-recommendation-history (user principal) (recommendation-id uint))
    (map-get? recommendation-history { user: user, recommendation-id: recommendation-id })
)


;; title: impromptu-adventure-recommendation-engine
;; version:
;; summary:
;; description:

;; traits
;;

;; token definitions
;;

;; constants
;;

;; data vars
;;

;; data maps
;;

;; public functions
;;

;; read only functions
;;

;; private functions
;;

