;; Calculated Whimsy Delivery System
;; Deploys algorithmic quirkiness at optimal intervals to maintain personality authenticity scores

;; Define error constants
(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-USER-NOT-FOUND (err u404))
(define-constant ERR-INVALID-WHIMSY (err u400))
(define-constant ERR-INSUFFICIENT-AUTHENTICITY (err u402))
(define-constant ERR-DEPLOYMENT-COOLDOWN (err u403))
(define-constant ERR-WHIMSY-OVERSATURATION (err u405))
(define-constant ERR-PERSONALITY-MISMATCH (err u406))

;; Whimsy type constants
(define-constant WHIMSY-TYPE-QUIRKY-COMMENT u1)
(define-constant WHIMSY-TYPE-RANDOM-FACT u2)
(define-constant WHIMSY-TYPE-UNEXPECTED-QUESTION u3)
(define-constant WHIMSY-TYPE-PLAYFUL-CHALLENGE u4)
(define-constant WHIMSY-TYPE-CREATIVE-PROMPT u5)
(define-constant WHIMSY-TYPE-AMUSING-OBSERVATION u6)

;; Personality archetype constants
(define-constant PERSONALITY-INTELLECTUAL u1)
(define-constant PERSONALITY-CREATIVE u2)
(define-constant PERSONALITY-SOCIAL u3)
(define-constant PERSONALITY-ADVENTUROUS u4)
(define-constant PERSONALITY-CONTEMPLATIVE u5)

;; System constants
(define-constant MIN-AUTHENTICITY-SCORE u30)
(define-constant MAX-AUTHENTICITY-SCORE u100)
(define-constant WHIMSY-COOLDOWN u3600) ;; 1 hour in seconds
(define-constant MAX-DAILY-WHIMSY u10)
(define-constant OPTIMAL-AUTHENTICITY-RANGE u75)

;; Data structures
(define-map personality-profiles principal {
    archetype: uint,
    authenticity-score: uint,
    quirkiness-level: uint,
    whimsy-preferences: (list 6 uint),
    deployment-intervals: (list 5 uint),
    last-whimsy-time: uint,
    daily-whimsy-count: uint,
    personality-consistency: uint,
    adaptation-rate: uint
})

(define-map whimsy-templates uint {
    content: (string-ascii 200),
    whimsy-type: uint,
    personality-alignment: (list 5 uint),
    complexity-score: uint,
    authenticity-impact: int,
    timing-sensitivity: uint,
    social-context: uint,
    frequency-weight: uint
})

(define-map whimsy-deployment-history (tuple (user principal) (deployment-id uint)) {
    timestamp: uint,
    whimsy-template-id: uint,
    calculated-authenticity-impact: int,
    actual-authenticity-impact: (optional int),
    user-response: (optional uint),
    context-factors: (list 5 uint),
    effectiveness-score: (optional uint)
})

(define-map daily-whimsy-tracking (tuple (user principal) (day uint)) {
    whimsy-count: uint,
    average-effectiveness: uint,
    authenticity-fluctuation: int,
    optimal-intervals-hit: uint,
    personality-drift: int
})

(define-map authenticity-audit-trail principal (list 20 {
    timestamp: uint,
    score-change: int,
    trigger-event: uint,
    whimsy-template-id: uint
}))

;; System variables
(define-data-var whimsy-template-counter uint u0)
(define-data-var deployment-counter uint u0)
(define-data-var contract-owner principal tx-sender)
(define-data-var global-whimsy-multiplier uint u100)

;; Initialize personality profile
(define-public (initialize-personality-profile 
    (archetype uint) 
    (quirkiness-level uint) 
    (preferences (list 6 uint))
    (intervals (list 5 uint))
    (adaptation-rate uint)
)
    (let (
        (current-time (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
    )
        (asserts! (is-none (map-get? personality-profiles tx-sender)) ERR-NOT-AUTHORIZED)
        (asserts! (<= archetype u5) ERR-INVALID-WHIMSY)
        (asserts! (<= quirkiness-level u100) ERR-INVALID-WHIMSY)
        (asserts! (<= adaptation-rate u100) ERR-INVALID-WHIMSY)
        
        (map-set personality-profiles tx-sender {
            archetype: archetype,
            authenticity-score: u70, ;; Starting authenticity
            quirkiness-level: quirkiness-level,
            whimsy-preferences: preferences,
            deployment-intervals: intervals,
            last-whimsy-time: u0,
            daily-whimsy-count: u0,
            personality-consistency: u80,
            adaptation-rate: adaptation-rate
        })
        
        ;; Initialize audit trail
        (map-set authenticity-audit-trail tx-sender (list {
            timestamp: current-time,
            score-change: 0,
            trigger-event: u0,
            whimsy-template-id: u0
        }))
        
        (ok true)
    )
)

;; Calculate and deploy optimal whimsy
(define-public (deploy-calculated-whimsy (context-factors (list 5 uint)))
    (let (
        (user-profile (unwrap! (map-get? personality-profiles tx-sender) ERR-USER-NOT-FOUND))
        (current-time (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
        (last-whimsy (get last-whimsy-time user-profile))
        (daily-count (get daily-whimsy-count user-profile))
        (deployment-id (var-get deployment-counter))
    )
        ;; Check deployment constraints
        (asserts! (>= (get authenticity-score user-profile) MIN-AUTHENTICITY-SCORE) ERR-INSUFFICIENT-AUTHENTICITY)
        (asserts! (> (- current-time last-whimsy) WHIMSY-COOLDOWN) ERR-DEPLOYMENT-COOLDOWN)
        (asserts! (< daily-count MAX-DAILY-WHIMSY) ERR-WHIMSY-OVERSATURATION)
        
        (let (
            (optimal-whimsy-id (calculate-optimal-whimsy user-profile context-factors))
            (authenticity-impact (predict-authenticity-impact user-profile optimal-whimsy-id context-factors))
            (deployment-timing-score (calculate-deployment-timing user-profile context-factors))
        )
            ;; Record deployment
            (map-set whimsy-deployment-history
                { user: tx-sender, deployment-id: deployment-id }
                {
                    timestamp: current-time,
                    whimsy-template-id: optimal-whimsy-id,
                    calculated-authenticity-impact: authenticity-impact,
                    actual-authenticity-impact: none,
                    user-response: none,
                    context-factors: context-factors,
                    effectiveness-score: none
                }
            )
            
            ;; Update user profile
            (map-set personality-profiles tx-sender
                (merge user-profile {
                    last-whimsy-time: current-time,
                    daily-whimsy-count: (+ daily-count u1),
                    authenticity-score: (update-authenticity-score 
                        (get authenticity-score user-profile) 
                        authenticity-impact
                    )
                })
            )
            
            ;; Update audit trail
            (update-authenticity-audit-trail tx-sender authenticity-impact u1 optimal-whimsy-id)
            
            ;; Increment deployment counter
            (var-set deployment-counter (+ deployment-id u1))
            
            (ok {
                deployment-id: deployment-id,
                whimsy-template-id: optimal-whimsy-id,
                predicted-impact: authenticity-impact,
                timing-score: deployment-timing-score,
                new-authenticity-score: (update-authenticity-score 
                    (get authenticity-score user-profile) 
                    authenticity-impact
                ),
                interval-optimization: (calculate-next-optimal-interval user-profile)
            })
        )
    )
)

;; Calculate optimal whimsy based on personality and context
(define-private (calculate-optimal-whimsy 
    (profile (tuple (archetype uint) (authenticity-score uint) (quirkiness-level uint) (whimsy-preferences (list 6 uint)) (deployment-intervals (list 5 uint)) (last-whimsy-time uint) (daily-whimsy-count uint) (personality-consistency uint) (adaptation-rate uint)))
    (context (list 5 uint))
)
    (let (
        (archetype (get archetype profile))
        (quirkiness (get quirkiness-level profile))
        (preferences (get whimsy-preferences profile))
        (authenticity (get authenticity-score profile))
    )
        ;; Algorithm to select whimsy type based on personality and context
        (if (is-eq archetype PERSONALITY-INTELLECTUAL)
            (if (>= quirkiness u70) WHIMSY-TYPE-UNEXPECTED-QUESTION WHIMSY-TYPE-RANDOM-FACT)
            (if (is-eq archetype PERSONALITY-CREATIVE)
                (if (>= authenticity u60) WHIMSY-TYPE-CREATIVE-PROMPT WHIMSY-TYPE-AMUSING-OBSERVATION)
                (if (is-eq archetype PERSONALITY-SOCIAL)
                    WHIMSY-TYPE-QUIRKY-COMMENT
                    (if (is-eq archetype PERSONALITY-ADVENTUROUS)
                        WHIMSY-TYPE-PLAYFUL-CHALLENGE
                        WHIMSY-TYPE-AMUSING-OBSERVATION
                    )
                )
            )
        )
    )
)

;; Predict authenticity impact of whimsy deployment
(define-private (predict-authenticity-impact 
    (profile (tuple (archetype uint) (authenticity-score uint) (quirkiness-level uint) (whimsy-preferences (list 6 uint)) (deployment-intervals (list 5 uint)) (last-whimsy-time uint) (daily-whimsy-count uint) (personality-consistency uint) (adaptation-rate uint)))
    (whimsy-id uint)
    (context (list 5 uint))
)
    (let (
        (current-authenticity (get authenticity-score profile))
        (personality-consistency (get personality-consistency profile))
        (daily-count (get daily-whimsy-count profile))
        (context-alignment (calculate-context-alignment context))
    )
        ;; Calculate impact based on multiple factors
        (let (
            (base-impact (if (>= personality-consistency u80) 5 2))
            (frequency-penalty (if (> daily-count u5) -3 0))
            (context-bonus (if (>= context-alignment u70) 3 0))
            (authenticity-adjustment (if (< current-authenticity OPTIMAL-AUTHENTICITY-RANGE) 2 -1))
        )
            (+ base-impact frequency-penalty context-bonus authenticity-adjustment)
        )
    )
)

;; Calculate deployment timing score
(define-private (calculate-deployment-timing 
    (profile (tuple (archetype uint) (authenticity-score uint) (quirkiness-level uint) (whimsy-preferences (list 6 uint)) (deployment-intervals (list 5 uint)) (last-whimsy-time uint) (daily-whimsy-count uint) (personality-consistency uint) (adaptation-rate uint)))
    (context (list 5 uint))
)
    (let (
        (intervals (get deployment-intervals profile))
        (current-time (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
        (last-whimsy (get last-whimsy-time profile))
        (time-since-last (- current-time last-whimsy))
    )
        ;; Score timing based on optimal intervals
        (let (
            (optimal-interval (unwrap-panic (element-at intervals u0)))
            (timing-variance (if (> time-since-last optimal-interval) 
                (- time-since-last optimal-interval)
                (- optimal-interval time-since-last)
            ))
            (timing-score (if (< timing-variance u1800) u100 ;; Within 30 minutes
                (if (< timing-variance u3600) u80 ;; Within 1 hour
                    (if (< timing-variance u7200) u60 u40) ;; Within 2 hours or more
                )
            ))
        )
            timing-score
        )
    )
)

;; Calculate context alignment score
(define-private (calculate-context-alignment (context (list 5 uint)))
    (let (
        (mood (unwrap-panic (element-at context u0)))
        (social-setting (unwrap-panic (element-at context u1)))
        (energy-level (unwrap-panic (element-at context u2)))
        (attention-level (unwrap-panic (element-at context u3)))
        (receptivity (unwrap-panic (element-at context u4)))
    )
        (/ (+ mood social-setting energy-level attention-level receptivity) u5)
    )
)

;; Update authenticity score with bounds checking
(define-private (update-authenticity-score (current-score uint) (impact int))
    (let (
        (new-score (+ (to-int current-score) impact))
    )
        (if (> new-score (to-int MAX-AUTHENTICITY-SCORE))
            MAX-AUTHENTICITY-SCORE
            (if (< new-score (to-int MIN-AUTHENTICITY-SCORE))
                MIN-AUTHENTICITY-SCORE
                (to-uint new-score)
            )
        )
    )
)

;; Calculate next optimal interval
(define-private (calculate-next-optimal-interval 
    (profile (tuple (archetype uint) (authenticity-score uint) (quirkiness-level uint) (whimsy-preferences (list 6 uint)) (deployment-intervals (list 5 uint)) (last-whimsy-time uint) (daily-whimsy-count uint) (personality-consistency uint) (adaptation-rate uint)))
)
    (let (
        (base-intervals (get deployment-intervals profile))
        (authenticity (get authenticity-score profile))
        (daily-count (get daily-whimsy-count profile))
        (adaptation (get adaptation-rate profile))
    )
        ;; Adjust intervals based on current state
        (let (
            (base-interval (unwrap-panic (element-at base-intervals u0)))
            (authenticity-modifier (if (< authenticity u50) u80 u120))
            (frequency-modifier (if (> daily-count u7) u130 u100))
        )
            (/ (* (* base-interval authenticity-modifier) frequency-modifier) u10000)
        )
    )
)

;; Update authenticity audit trail
(define-private (update-authenticity-audit-trail (user principal) (score-change int) (event-type uint) (template-id uint))
    (let (
        (current-time (unwrap-panic (get-stacks-block-info? time (- stacks-block-height u1))))
        (current-trail (default-to (list) (map-get? authenticity-audit-trail user)))
        (new-entry {
            timestamp: current-time,
            score-change: score-change,
            trigger-event: event-type,
            whimsy-template-id: template-id
        })
    )
        (map-set authenticity-audit-trail user 
            (unwrap-panic (as-max-len? (append current-trail new-entry) u20))
        )
    )
)

;; Record user response to deployed whimsy
(define-public (record-whimsy-response (deployment-id uint) (response-score uint) (effectiveness uint))
    (let (
        (deployment-key { user: tx-sender, deployment-id: deployment-id })
        (deployment-data (unwrap! (map-get? whimsy-deployment-history deployment-key) ERR-USER-NOT-FOUND))
    )
        (asserts! (<= response-score u100) ERR-INVALID-WHIMSY)
        (asserts! (<= effectiveness u100) ERR-INVALID-WHIMSY)
        
        (map-set whimsy-deployment-history deployment-key
            (merge deployment-data {
                user-response: (some response-score),
                effectiveness-score: (some effectiveness)
            })
        )
        (ok true)
    )
)

;; Analyze personality consistency
(define-public (analyze-personality-consistency)
    (let (
        (user-profile (unwrap! (map-get? personality-profiles tx-sender) ERR-USER-NOT-FOUND))
        (audit-trail (default-to (list) (map-get? authenticity-audit-trail tx-sender)))
    )
        (let (
            (recent-fluctuations (calculate-authenticity-variance audit-trail))
            (consistency-score (calculate-consistency-score recent-fluctuations))
            (personality-drift (calculate-personality-drift user-profile audit-trail))
        )
            (ok {
                consistency-score: consistency-score,
                authenticity-variance: recent-fluctuations,
                personality-drift: personality-drift,
                recommendation: (get-consistency-recommendation consistency-score),
                current-authenticity: (get authenticity-score user-profile)
            })
        )
    )
)

;; Calculate authenticity variance from audit trail
(define-private (calculate-authenticity-variance (trail (list 20 (tuple (timestamp uint) (score-change int) (trigger-event uint) (whimsy-template-id uint)))))
    (fold calculate-variance-step trail { sum: 0, count: u0, variance: u0 })
)

;; Helper function for variance calculation
(define-private (calculate-variance-step 
    (entry (tuple (timestamp uint) (score-change int) (trigger-event uint) (whimsy-template-id uint))) 
    (acc (tuple (sum int) (count uint) (variance uint)))
)
    {
        sum: (+ (get sum acc) (get score-change entry)),
        count: (+ (get count acc) u1),
        variance: (+ (get variance acc) (to-uint (* (get score-change entry) (get score-change entry))))
    }
)

;; Calculate consistency score
(define-private (calculate-consistency-score (variance-data (tuple (sum int) (count uint) (variance uint))))
    (let (
        (variance (get variance variance-data))
        (count (get count variance-data))
    )
        (if (is-eq count u0) u50
            (let (
                (average-variance (/ variance count))
            )
                (if (< average-variance u25) u90
                    (if (< average-variance u100) u70
                        (if (< average-variance u400) u50 u30)
                    )
                )
            )
        )
    )
)

;; Calculate personality drift
(define-private (calculate-personality-drift 
    (profile (tuple (archetype uint) (authenticity-score uint) (quirkiness-level uint) (whimsy-preferences (list 6 uint)) (deployment-intervals (list 5 uint)) (last-whimsy-time uint) (daily-whimsy-count uint) (personality-consistency uint) (adaptation-rate uint)))
    (trail (list 20 (tuple (timestamp uint) (score-change int) (trigger-event uint) (whimsy-template-id uint))))
)
    (let (
        (recent-authenticity (get authenticity-score profile))
        (base-authenticity u70) ;; Initial authenticity score
    )
        (to-int (if (> recent-authenticity base-authenticity)
            (- recent-authenticity base-authenticity)
            (- base-authenticity recent-authenticity)
        ))
    )
)

;; Get consistency recommendation (returns recommendation code)
(define-private (get-consistency-recommendation (score uint))
    (if (>= score u80) u1 ;; Maintain current patterns
        (if (>= score u60) u2 ;; Slight adjustment needed
            (if (>= score u40) u3 ;; Diversify whimsy types
                u4 ;; Significant recalibration needed
            )
        )
    )
)

;; Add whimsy template (admin function)
(define-public (add-whimsy-template 
    (content (string-ascii 200))
    (whimsy-type uint)
    (personality-alignment (list 5 uint))
    (complexity-score uint)
    (authenticity-impact int)
    (timing-sensitivity uint)
    (social-context uint)
    (frequency-weight uint)
)
    (let (
        (template-id (var-get whimsy-template-counter))
    )
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (asserts! (<= whimsy-type u6) ERR-INVALID-WHIMSY)
        
        (map-set whimsy-templates template-id {
            content: content,
            whimsy-type: whimsy-type,
            personality-alignment: personality-alignment,
            complexity-score: complexity-score,
            authenticity-impact: authenticity-impact,
            timing-sensitivity: timing-sensitivity,
            social-context: social-context,
            frequency-weight: frequency-weight
        })
        
        (var-set whimsy-template-counter (+ template-id u1))
        (ok template-id)
    )
)

;; Read-only functions
(define-read-only (get-personality-profile (user principal))
    (map-get? personality-profiles user)
)

(define-read-only (get-authenticity-score (user principal))
    (match (map-get? personality-profiles user)
        profile (ok (get authenticity-score profile))
        ERR-USER-NOT-FOUND
    )
)

(define-read-only (get-whimsy-template (template-id uint))
    (map-get? whimsy-templates template-id)
)

(define-read-only (get-deployment-history (user principal) (deployment-id uint))
    (map-get? whimsy-deployment-history { user: user, deployment-id: deployment-id })
)

(define-read-only (get-authenticity-audit (user principal))
    (map-get? authenticity-audit-trail user)
)

(define-read-only (get-daily-whimsy-stats (user principal) (day uint))
    (map-get? daily-whimsy-tracking { user: user, day: day })
)
