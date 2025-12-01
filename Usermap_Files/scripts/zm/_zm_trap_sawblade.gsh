// ====================================================================
// Sawblade Trap - Configuration Header
// ====================================================================

// Trap settings
#define SAWBLADE_TRAP_REQUIRES_POWER        false        // Set to false to allow activation without power
#define SAWBLADE_TRAP_COST                  1000        // Cost to activate
#define SAWBLADE_TRAP_DURATION              25          // Duration in seconds
#define SAWBLADE_TRAP_COOLDOWN              30          // Cooldown in seconds

// Damage settings
#define SAWBLADE_TRAP_ZOMBIE_DAMAGE         1500        // Damage to zombies
#define SAWBLADE_TRAP_PLAYER_DAMAGE         50          // Damage to players
#define SAWBLADE_TRAP_PLAYER_COOLDOWN       1.0         // Player damage cooldown

// Asset names
#define SAWBLADE_TRAP_MODEL                 "sat_zm_sawblade_trap_set_fxanim"
#define SAWBLADE_TRAP_LEVER_MODEL           "sat_zm_sawblade_trap_lever"

// Trigger settings
#define SAWBLADE_TRAP_DAMAGE_RADIUS         120         // Damage detection radius
#define SAWBLADE_TRAP_DAMAGE_HEIGHT         100         // Damage detection height
#define SAWBLADE_TRAP_USE_RADIUS            64          // Unitrigger activation radius
#define SAWBLADE_TRAP_USE_HEIGHT            80          // Unitrigger activation height

// Player knockback settings
#define SAWBLADE_TRAP_KNOCKBACK_HORIZONTAL  400         // Horizontal push force
#define SAWBLADE_TRAP_KNOCKBACK_VERTICAL    200         // Upward launch force

// Zombie attraction settings
#define SAWBLADE_TRAP_ATTRACT_DISTANCE      1536        // Max distance zombies are attracted from
#define SAWBLADE_TRAP_ATTRACT_COUNT         96          // Max number of zombies attracted
#define SAWBLADE_TRAP_ATTRACT_PRIORITY      10000       // Priority value (higher = stronger attraction)
