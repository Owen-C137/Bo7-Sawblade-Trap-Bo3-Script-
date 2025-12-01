// ====================================================================
// Sawblade Trap - Server Script (Unitrigger System)
// ====================================================================

#using scripts\codescripts\struct;
#using scripts\shared\ai\systems\gib;
#using scripts\shared\array_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#using scripts\zm\_zm_audio;
#using scripts\zm\_zm_score;
#using scripts\zm\_zm_stats;
#using scripts\zm\_zm_traps;
#using scripts\zm\_zm_unitrigger;
#using scripts\zm\_zm_utility;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#insert scripts\zm\_zm_trap_sawblade.gsh;

#using_animtree("zm_sawblade_trap");

#precache("xanim", "sat_zm_sawblade_trap_active_loop");
#precache("xanim", "sat_zm_sawblade_trap_stop");
#precache("xanim", "sat_zm_sawblade_trap_lever_activate");
#precache("xanim", "sat_zm_sawblade_trap_lever_deactivate");

#precache("fx", "_OwensAssets/bo7/sawblade_trap/sawblade_spinning_swirl");

#namespace zm_trap_sawblade;

// ====================================================================
// SYSTEM REGISTRATION
// ====================================================================

REGISTER_SYSTEM_EX("zm_trap_sawblade", &__init__, &__main__, undefined)

// ====================================================================
// INITIALIZATION
// ====================================================================

function __init__()
{
    // Register trap damage functions with zm_traps system (for stats)
    zm_traps::register_trap_damage("sawblade", &player_damage_sawblade, &zombie_damage_sawblade);
}

function __main__()
{
    // Register FX effects
    level._effect["sawblade_spinning_swirl"] = "_OwensAssets/bo7/sawblade_trap/sawblade_spinning_swirl";
    
    // Setup all sawblade trap levers in the map (before power so we can show "no power" hint)
    trap_levers = GetEntArray("sawblade_trap_lever", "targetname");
    trap_models = GetEntArray("sawblade_trap_model", "targetname");
    trap_triggers = GetEntArray("sawblade_trap_damage", "targetname");
    
    if(!IsDefined(trap_levers) || trap_levers.size == 0)
    {
        return;
    }
    
    // Validate and initialize each trap
    foreach(lever in trap_levers)
    {
        if(!IsDefined(lever.script_int))
        {
            continue;
        }
        
        // Find matching blade and trigger with same script_int
        blade = get_trap_component_by_script_int(trap_models, lever.script_int);
        trigger = get_trap_component_by_script_int(trap_triggers, lever.script_int);
        
        if(!IsDefined(blade) || !IsDefined(trigger))
        {
            continue;
        }
        
        // All components found - initialize this trap
        lever thread init_sawblade_trap(blade, trigger);
    }
}

function get_trap_component_by_script_int(components, script_int_value)
{
    if(!IsDefined(components))
        return undefined;
        
    foreach(component in components)
    {
        if(IsDefined(component.script_int) && component.script_int == script_int_value)
        {
            return component;
        }
    }
    
    return undefined;
}

// ====================================================================
// TRAP INITIALIZATION
// ====================================================================

function init_sawblade_trap(trap_model, damage_trigger)
{
    // self = lever model
    
    // If components not passed in, find them by script_int (fallback)
    if(!IsDefined(trap_model))
    {
        if(IsDefined(self.script_int))
        {
            trap_models = GetEntArray("sawblade_trap_model", "targetname");
            
            foreach(model in trap_models)
            {
                if(IsDefined(model.script_int) && model.script_int == self.script_int)
                {
                    trap_model = model;
                    break;
                }
            }
        }
        
        if(!IsDefined(trap_model))
        {
            return;
        }
    }
    
    if(!IsDefined(damage_trigger))
    {
        if(IsDefined(self.script_int))
        {
            all_triggers = GetEntArray("sawblade_trap_damage", "targetname");
            
            foreach(trigger in all_triggers)
            {
                if(IsDefined(trigger.script_int) && trigger.script_int == self.script_int)
                {
                    damage_trigger = trigger;
                    break;
                }
            }
        }
        
        if(!IsDefined(damage_trigger))
        {
            return;
        }
    }
    
    // Setup animtree for both models
    trap_model useanimtree(#animtree);
    self useanimtree(#animtree);
    
    // Initialize lever bones - hide all first
    self hidepart("bone_72975cce9f403ba6"); // Off (no power)
    self hidepart("bone_a10d86d9130ff7c6"); // Ready/Green
    self hidepart("bone_5e8e68bd438d320b"); // Active/Yellow
    self hidepart("bone_75d6d5ce0fa69abc"); // Cooldown/Red
    
    // Show correct state based on power requirement
    if(!SAWBLADE_TRAP_REQUIRES_POWER || level flag::get("power_on"))
    {
        self showpart("bone_a10d86d9130ff7c6"); // Ready/Green
    }
    else
    {
        self showpart("bone_72975cce9f403ba6"); // Off (no power)
        self thread wait_for_power_then_ready();
    }
    
    // Store references
    self.trap_model = trap_model;
    self.lever_model = self;
    self.damage_trigger = damage_trigger;
    self._trap_in_use = false;
    self._trap_cooling_down = false;
    self.zombie_cost = SAWBLADE_TRAP_COST;
    self._trap_duration = SAWBLADE_TRAP_DURATION;
    self._trap_cooldown_time = SAWBLADE_TRAP_COOLDOWN;
    
    // Create unitrigger on the lever for player interaction
    unitrigger_stub = SpawnStruct();
    unitrigger_stub.origin = self.origin;
    unitrigger_stub.angles = self.angles;
    unitrigger_stub.script_unitrigger_type = "unitrigger_radius_use";
    unitrigger_stub.radius = SAWBLADE_TRAP_USE_RADIUS;
    unitrigger_stub.height = SAWBLADE_TRAP_USE_HEIGHT;
    unitrigger_stub.cursor_hint = "HINT_NOICON";
    unitrigger_stub.require_look_at = false;
    unitrigger_stub.trap_lever = self;
    unitrigger_stub.prompt_and_visibility_func = &sawblade_trap_update_hint;
    
    zm_unitrigger::register_static_unitrigger(unitrigger_stub, &sawblade_trap_think);
}

// ====================================================================
// UNITRIGGER SYSTEM
// ====================================================================

function sawblade_trap_think()
{
    self endon("kill_trigger");
    
    while(true)
    {
        // Get lever reference from stub each time (CRITICAL for multiple traps)
        trap_lever = self.stub.trap_lever;
        
        // Wait for cooldown to clear before accepting triggers (official pattern)
        if(trap_lever._trap_cooling_down)
        {
            while(trap_lever._trap_cooling_down)
            {
                wait(0.1);
            }
        }
        
        self waittill("trigger", player);
        
        // Validate player state (official trap pattern)
        if(player zm_utility::in_revive_trigger())
        {
            continue;
        }
        
        if(player.is_drinking > 0)
        {
            continue;
        }
        
        if(!zm_utility::is_player_valid(player))
        {
            continue;
        }
        
        // Check if power is on (if required)
        if(SAWBLADE_TRAP_REQUIRES_POWER && !level flag::get("power_on"))
        {
            continue;
        }
        
        // Check if trap is in use or cooling down
        if(trap_lever._trap_in_use || trap_lever._trap_cooling_down)
        {
            continue;
        }
        
        // Check if player has enough points (use official function)
        if(!player zm_score::can_player_purchase(trap_lever.zombie_cost))
        {
            player zm_audio::create_and_play_dialog("general", "outofmoney");
            continue;
        }
        
        // Deduct cost
        player zm_score::minus_to_player_score(trap_lever.zombie_cost);
        
        // Store activating player for stats
        trap_lever.activated_by_player = player;
        
        // Activate trap
        trap_lever thread trap_activate_sawblade();
    }
}

function sawblade_trap_update_hint(player)
{
    trap_lever = self.stub.trap_lever;
    
    if(!IsDefined(trap_lever))
    {
        self sethintstring("");
        return false;
    }
    
    // Hide trigger if player is drinking (official trap pattern)
    if(player.is_drinking > 0)
    {
        self sethintstring("");
        return false;
    }
    
    // Check if power is on (if required)
    if(SAWBLADE_TRAP_REQUIRES_POWER && !level flag::get("power_on"))
    {
        self sethintstring(&"ZOMBIE_NEED_POWER");
        return false;
    }
    
    // Hide trigger when trap is active
    if(trap_lever._trap_in_use)
    {
        self sethintstring("");
        return false;
    }
    
    // Show cooldown message
    if(trap_lever._trap_cooling_down)
    {
        self sethintstring(&"ZOMBIE_TRAP_COOLDOWN");
        return false;
    }
    
    // Show purchase hint with cost
    self sethintstring(&"ZOMBIE_BUTTON_BUY_TRAP", trap_lever.zombie_cost);
    return true;
}

// ====================================================================
// TRAP ACTIVATION
// ====================================================================

function trap_activate_sawblade()
{
    // Don't use endon("trap_done") here - we need cooldown code to run after trap ends
    
    if(!IsDefined(self.trap_model))
    {
        return;
    }
    
    // Mark trap as in use
    self._trap_in_use = true;
    
    // Spawn FX helper model on blade bone
    bone_origin = self.trap_model GetTagOrigin("bone_93ed55773123f223");
    self.fx_model = Spawn("script_model", bone_origin);
    self.fx_model SetModel("tag_origin");
    self.fx_model LinkTo(self.trap_model, "bone_93ed55773123f223");
    
    // Play FX on helper model
    playfxontag(level._effect["sawblade_spinning_swirl"], self.fx_model, "tag_origin");
    
    // Play lever trigger sound
    if(IsDefined(self.lever_model))
    {
        self.lever_model PlaySound("sawblade_lever_trigger");
    }
    
    // Change lever to active state (yellow) before playing animation
    if(IsDefined(self.lever_model))
    {
        // Hide ready (green), show active (yellow)
        self.lever_model hidepart("bone_a10d86d9130ff7c6");
        self.lever_model showpart("bone_5e8e68bd438d320b");
    }
    
    // Play blade spinning animation (looping)
    self.trap_model thread play_blade_animation("sat_zm_sawblade_trap_active_loop");
    
    // Spawn invisible script_origin for second sound
    self.sound_ent = Spawn("script_origin", self.trap_model.origin);
    wait(0.05);  // Small delay for entity to initialize
    
    // Play both loop sounds on DIFFERENT entities
    self.trap_model PlayLoopSound("sawblade_trap_active_loop");  // Blade spinning sound
    self.sound_ent PlayLoopSound("sawblade_trap_lure");          // Zombie attraction sound
    
    // Play lever activate animation
    if(IsDefined(self.lever_model))
    {
        self.lever_model thread play_lever_animation("sat_zm_sawblade_trap_lever_activate");
    }
    
    // Start zombie attraction
    self.trap_model thread attract_zombies_to_trap(self);
    
    // Start damage detection using both trigger AND polling for reliability
    self.damage_trigger thread trap_damage_think(self);
    self thread trap_damage_poll();
    
    // Wait for most of trap duration
    wait_time = self._trap_duration - 3;
    if(wait_time > 0)
    {
        self util::waittill_notify_or_timeout("trap_deactivate", wait_time);
    }
    
    // Change lever to cooldown state (red) a few seconds before stopping
    if(IsDefined(self.lever_model))
    {
        self.lever_model hidepart("bone_5e8e68bd438d320b");
        self.lever_model showpart("bone_75d6d5ce0fa69abc");
    }
    
    // Wait remaining time
    wait(3);
    
    // Stop zombie attraction and restore normal behavior
    self.trap_model notify("trap_stop_attraction");
    
    // Deactivate point of interest (keeps entity but stops attraction)
    self.trap_model zm_utility::deactivate_zombie_point_of_interest(true);
    
    // Delete FX helper for instant stop
    if(IsDefined(self.fx_model))
    {
        self.fx_model Delete();
        self.fx_model = undefined;
    }
    
    // Stop both loop sounds
    self.trap_model StopLoopSound();
    
    if(IsDefined(self.sound_ent))
    {
        self.sound_ent StopLoopSound();
        self.sound_ent Delete();
        self.sound_ent = undefined;
    }
    
    // Stop the blade animation
    self.trap_model notify("stop_blade_anim");
    self.trap_model thread play_blade_animation("sat_zm_sawblade_trap_stop");
    
    // Play lever reset sound and animation
    if(IsDefined(self.lever_model))
    {
        self.lever_model PlaySound("sawblade_lever_trigger");
        self.lever_model thread play_lever_animation("sat_zm_sawblade_trap_lever_deactivate");
    }
    
    // Mark trap as no longer in use, but cooling down
    self._trap_in_use = false;
    self._trap_cooling_down = true;
    
    self notify("trap_done");
    
    // Store references before threading
    lever = self;
    
    // Wait for cooldown
    wait(self._trap_cooldown_time);
    
    // Clear cooling down flag
    lever._trap_cooling_down = false;
    
    // Change from cooldown (red) back to ready (green)
    if(IsDefined(lever.lever_model))
    {
        lever.lever_model hidepart("bone_75d6d5ce0fa69abc");
        lever.lever_model showpart("bone_a10d86d9130ff7c6");
    }
    
    // Play ready sound
    if(IsDefined(lever.lever_model))
    {
        PlaySoundAtPosition("zmb_trap_ready", lever.lever_model.origin);
    }
}

function wait_for_power_then_ready()
{
    // Wait for power to be turned on (if required)
    if(SAWBLADE_TRAP_REQUIRES_POWER)
    {
        level flag::wait_till("power_on");
    }
    
    // Switch from off (no power) to ready (green)
    if(IsDefined(self))
    {
        self hidepart("bone_72975cce9f403ba6"); // Off
        self showpart("bone_a10d86d9130ff7c6"); // Ready/Green
    }
}

// ====================================================================
// DAMAGE DETECTION (Hybrid: trigger_damage + polling for stationary zombies)
// ====================================================================

function trap_damage_poll()
{
    self endon("trap_done");
    
    trap_origin = self.trap_model.origin;
    damage_radius = 60;  // Slightly smaller than trigger
    
    while(true)
    {
        // Poll for zombies inside the trap area (catches stationary zombies)
        zombies = GetAITeamArray("axis");
        
        foreach(zombie in zombies)
        {
            if(!IsAlive(zombie))
                continue;
                
            dist = Distance(zombie.origin, trap_origin);
            
            if(dist < damage_radius)
            {
                if(!IsDefined(zombie.marked_for_death))
                {
                    zombie thread zombie_damage_sawblade(self);
                }
            }
        }
        
        wait(0.2);  // Check 5 times per second
    }
}

function trap_damage_think(parent_trap)
{
    parent_trap endon("trap_done");
    self._trap_type = "sawblade";
    
    while(true)
    {
        self waittill("trigger", ent);
        
        // Check if entity is valid
        if(!IsDefined(ent))
        {
            continue;
        }
        
        // trigger_multiple only fires when entities physically enter
        // It does NOT fire on bullets (unlike trigger_damage)
        if(IsPlayer(ent))
        {
            ent thread player_damage_sawblade(parent_trap.trap_model.origin);
        }
        else if(IsAI(ent) && IsAlive(ent))
        {
            if(!IsDefined(ent.marked_for_death))
            {
                ent thread zombie_damage_sawblade(parent_trap);
            }
        }
        
        wait(0.05);
    }
}

// ====================================================================
// PLAYER DAMAGE
// ====================================================================

function player_damage_sawblade(blade_origin)
{
    self endon("death");
    self endon("disconnect");
    
    if(!zm_utility::is_player_valid(self))
    {
        return;
    }
    
    if(IsDefined(self.sawblade_damage_cooldown))
    {
        return;
    }
    
    self.sawblade_damage_cooldown = true;
    
    // Calculate knockback direction (away from blade)
    direction = VectorNormalize(self.origin - blade_origin);
    direction = (direction[0], direction[1], 0); // Keep horizontal only
    
    // Apply knockback velocity
    velocity = direction * SAWBLADE_TRAP_KNOCKBACK_HORIZONTAL; // Horizontal push
    velocity = (velocity[0], velocity[1], SAWBLADE_TRAP_KNOCKBACK_VERTICAL); // Add upward launch
    self SetVelocity(velocity);
    
    // Deal damage
    self DoDamage(SAWBLADE_TRAP_PLAYER_DAMAGE, self.origin);
    
    // Cooldown
    wait(SAWBLADE_TRAP_PLAYER_COOLDOWN);
    self.sawblade_damage_cooldown = undefined;
}

// ====================================================================
// ZOMBIE DAMAGE
// ====================================================================

function zombie_damage_sawblade(trap)
{
    self endon("death");
    
    // Set marked_for_death flag (official trap pattern)
    self.marked_for_death = true;
    
    // Increment trap kill stat for activating player
    if(IsDefined(trap.activated_by_player) && IsPlayer(trap.activated_by_player))
    {
        trap.activated_by_player zm_stats::increment_challenge_stat("ZOMBIE_HUNTER_KILL_TRAP");
    }
    
    // Notify challenge system of trap kill (if challenge system exists)
    if(IsDefined(level.challenge_active) && level.challenge_active)
    {
        level notify("trap_kill");
    }
    
    // Kill the zombie with sawblade death animation
    self thread zombie_sawblade_death(trap);
}

function zombie_sawblade_death(trap)
{
    self endon("death");
    
    // Play zombie death sound
    PlaySoundAtPosition("sawblade_zmb_death", self.origin);
    
    // Gib/dismember the zombie for sawblade effect (head, arms, legs)
    if(!(IsDefined(self.no_gib) && self.no_gib))
    {
        gibserverutils::gibhead(self);
    }
    gibserverutils::gibleftarm(self);
    gibserverutils::gibrightarm(self);
    gibserverutils::giblegs(self);
    
    // Deal fatal damage
    self DoDamage(self.health + 666, self.origin, trap, trap, "MOD_UNKNOWN");
}

// ====================================================================
// ZOMBIE ATTRACTION (Make zombies target trap instead of players)
// ====================================================================

function attract_zombies_to_trap(parent_trap)
{
    parent_trap endon("trap_done");
    self endon("trap_stop_attraction");
    
    // Use official BO3 point of interest system (like monkey bombs)
    // attract_dist, num_attractors, added_poi_value, start_turned_on
    self zm_utility::create_zombie_point_of_interest(SAWBLADE_TRAP_ATTRACT_DISTANCE, SAWBLADE_TRAP_ATTRACT_COUNT, SAWBLADE_TRAP_ATTRACT_PRIORITY, true);
    self.attract_to_origin = 1;
    
    // Wait for trap to end
    parent_trap waittill("trap_done");
}

// ====================================================================
// ANIMATION PLAYBACK
// ====================================================================

function play_blade_animation(anim_name)
{
    self endon("death");
    self endon("stop_blade_anim");
    
    if(!IsDefined(self))
        return;
    
    // Play the animation using AnimScripted
    self AnimScripted(anim_name, self.origin, self.angles, anim_name);
}

function play_lever_animation(anim_name)
{
    self endon("death");
    
    if(!IsDefined(self))
        return;
    
    // Play the animation using AnimScripted
    self AnimScripted(anim_name, self.origin, self.angles, anim_name);
}
