# BO7 Sawblade Trap for Black Ops 3 Zombies

A fully functional, configurable sawblade trap system inspired by Black Ops 7, ported to Black Ops 3 custom zombies maps.     

## Features

-  **Fully animated sawblade trap** with spinning blade and lever activation
-  **Player knockback system** - launches players away from the blade with configurable force
-  **Zombie attraction** - uses official BO3 point of interest system (like monkey bombs)
-  **Instant kill zombies** with gibbing/dismemberment effects
-  **Wind swirl FX** on spinning blade
-  **Custom sounds** - lever activation, blade spinning loop, zombie lure audio
-  **Visual state system** - lever shows green (ready), yellow (active), red (cooldown), gray (no power)
-  **Power requirement toggle** - can be enabled/disabled
-  **Fully configurable** - all settings in `.gsh` header file
-  **Multiple trap support** - place as many traps as you want in your map

## Installation

### Step 1: Install Assets (BO3 Root Directory)

Drag and drop the contents of the **`BO3_Root`** folder into your Black Ops 3 root directory:
```
Call of Duty Black Ops III\
```

This will add the following files to your BO3 installation:
- `share\raw\fx\_OwensAssets\bo7\sawblade_trap\` - FX files
- `share\raw\sound\aliases\sawblade_trap.csv` - Sound aliases
- `map_source\_prefabs\_OwensAssets\bo7\sawblade\sawblade_trap.map` - Radiant prefab
- `model_export\_OwensAssets\bo7\sawblade_trap\` - Model files
- `sound_assets\_OwensAssets\bo7\sawblade_trap\` - Sound files

### Step 2: Add to Your Usermap

Copy the contents of **`Usermap_Files`** into your usermap folder:
```
usermaps\YOUR_MAP_NAME\
```

This adds:
- `animtrees\zm_sawblade_trap.atr` - Animation tree
- `scripts\zm\_zm_trap_sawblade.gsc` - Main trap script
- `scripts\zm\_zm_trap_sawblade.gsh` - Configuration header

### Step 3: Register Sound in Usermap

Open or create your map's sound zoneconfig file:
```
usermaps\YOUR_MAP_NAME\sound\zoneconfig\YOUR_MAP_NAME.szc
```

Add this entry to the `"Sources"` array:
```json
{
 "Type" : "ALIAS",
 "Name" : "sawblade_trap",
 "Filename" : "sawblade_trap.csv",
 "Specs" : [ ]
},
```

### Step 4: Update Your Zone File

Open your zone file:
```
usermaps\YOUR_MAP_NAME\zone_source\YOUR_MAP_NAME.zone
```

Add these entries:

```
// Sawblade Trap Script Files
scriptparsetree,scripts/zm/_zm_trap_sawblade.gsc
scriptparsetree,scripts/zm/_zm_trap_sawblade.gsh

// Sawblade Trap Models
xmodel,sat_zm_sawblade_trap_set_fxanim
xmodel,sat_zm_sawblade_trap_lever

// Sawblade Trap Animation Tree
rawfile,animtrees/zm_sawblade_trap.atr

// Sawblade Trap Animations
xanim,sat_zm_sawblade_trap_active_loop
xanim,sat_zm_sawblade_trap_stop
xanim,sat_zm_sawblade_trap_lever_activate
xanim,sat_zm_sawblade_trap_lever_deactivate

// Sawblade Trap FX
fx,_OwensAssets/bo7/sawblade_trap/sawblade_spinning_swirl
```

### Step 5: Load in Main GSC

Open your main map GSC file:
```
usermaps\YOUR_MAP_NAME\scripts\zm\YOUR_MAP_NAME.gsc
```

Add this `#using` statement at the top:
```gsc
#using scripts\zm\_zm_trap_sawblade;
```

## Radiant Setup

### Method 1: Use the Prefab (Easiest)

1. Open your map in Radiant
2. Go to **File  Import  Prefab**
3. Navigate to: `map_source\_prefabs\_OwensAssets\bo7\sawblade\sawblade_trap.map`
4. Place the prefab in your map
5. Done! The prefab includes:
   - Sawblade trap model (`script_model` with `targetname: "sawblade_trap_model"`)
   - Lever model (`script_model` with `targetname: "sawblade_trap_lever"`)
   - Damage trigger (`trigger_multiple` with `targetname: "sawblade_trap_damage"`)
   - All entities have matching `script_int` values to link them together

#### Adding Multiple Traps

To add multiple independent traps to your map:
(There is 3 premade prefabs for you to just drag in and use )

1. **Import the prefab** as described above and place the first trap
2. **Import the prefab again** for the second trap location and stamp it
3. **Select all entities of the second trap** (blade, lever, and trigger)
4. **Open the entity properties** (press `N`)
5. **Change the `script_int` value** from `1` to `2` for all three entities
6. Repeat for additional traps, using `script_int: 3`, `4`, `5`, etc.

**Each trap must have a unique `script_int` value**, but all three components of each trap (blade, lever, trigger) must share the **same** `script_int` to link them together.

**Example:**
- **Trap 1:** Blade, lever, and trigger all have `script_int: 1`
- **Trap 2:** Blade, lever, and trigger all have `script_int: 2`
- **Trap 3:** Blade, lever, and trigger all have `script_int: 3`

### Method 2: Manual Setup

If you want to set up the trap manually:

#### 1. Place the Blade Model
- Add a `script_model` entity
- Set `model: "sat_zm_sawblade_trap_set_fxanim"`
- Set `targetname: "sawblade_trap_model"`
- Set `script_int: 1` (or any unique number)

#### 2. Place the Lever Model
- Add a `script_model` entity
- Set `model: "sat_zm_sawblade_trap_lever"`
- Set `targetname: "sawblade_trap_lever"`
- Set `script_int: 1` (must match blade's script_int)

#### 3. Create the Damage Trigger
- Create a brush and right-click  **trigger  multiple**
- Set `targetname: "sawblade_trap_damage"`
- Set `script_int: 1` (must match blade's script_int)
- Size it to cover the blade's damage area (recommended: 120 units radius around blade)

**CRITICAL:** All three entities (blade, lever, damage trigger) must have the **same `script_int` value** to link them together. If you have multiple traps in your map, use different `script_int` values for each trap (1, 2, 3, etc.).

## Configuration

All trap settings can be configured in `scripts\zm\_zm_trap_sawblade.gsh`:

### Trap Behavior
```gsc
#define SAWBLADE_TRAP_REQUIRES_POWER        false   // true = needs power, false = works without power
#define SAWBLADE_TRAP_COST                  1000    // Activation cost in points
#define SAWBLADE_TRAP_DURATION              25      // Duration in seconds
#define SAWBLADE_TRAP_COOLDOWN              30      // Cooldown in seconds
```

### Damage Settings
```gsc
#define SAWBLADE_TRAP_ZOMBIE_DAMAGE         1500    // Instant kill zombies
#define SAWBLADE_TRAP_PLAYER_DAMAGE         50      // Player damage amount
#define SAWBLADE_TRAP_PLAYER_COOLDOWN       1.0     // Time between player hits (seconds)
```

### Player Knockback
```gsc
#define SAWBLADE_TRAP_KNOCKBACK_HORIZONTAL  400     // Horizontal push force (higher = stronger)
#define SAWBLADE_TRAP_KNOCKBACK_VERTICAL    200     // Upward launch force (higher = more lift)
```

### Zombie Attraction
```gsc
#define SAWBLADE_TRAP_ATTRACT_DISTANCE      1536    // Max distance zombies attracted from (~38 meters)
#define SAWBLADE_TRAP_ATTRACT_COUNT         96      // Max number of zombies attracted at once
#define SAWBLADE_TRAP_ATTRACT_PRIORITY      10000   // Attraction strength (10000 = monkey bomb level)
```

### Interaction Settings
```gsc
#define SAWBLADE_TRAP_USE_RADIUS            64      // How close to stand to activate (~1.6 meters)
#define SAWBLADE_TRAP_USE_HEIGHT            80      // Vertical activation range
```

## How It Works

1. **Player activates trap** by pressing the use key near the lever
2. **Lever animates** and changes from green to yellow (active state)
3. **Blade spins** with looping animation and wind swirl FX
4. **Zombies are attracted** using BO3's official point of interest system (same as monkey bombs)
5. **Zombies that touch the blade** are instantly killed with gib/dismemberment
6. **Players that touch the blade** are knocked back and take damage
7. **After duration ends**, lever changes to red (cooldown) and blade stops
8. **After cooldown**, lever returns to green (ready) state

## Troubleshooting

### Trap doesn't appear in Radiant
- Make sure you've copied all assets to the BO3 root directory
- Restart Radiant after copying assets

### Compile errors
- Verify all zone file entries are added correctly
- Check that `#using scripts\zm\_zm_trap_sawblade;` is in your main GSC
- Make sure `sawblade_trap.csv` is registered in your `.szc` sound config

### Trap doesn't work in-game
- Check console log (`console_mp.log`) for errors
- Verify all three entities (blade, lever, trigger) have **matching `script_int` values**
- Make sure trigger is `trigger_multiple` (not `trigger_damage`)
- If power requirement is on, verify power is activated

### Multiple traps interfere with each other
- Ensure each trap has a **unique `script_int` value** (Trap 1 = 1, Trap 2 = 2, etc.)
- Verify all three components of each trap share the same `script_int`

### FX not showing
- Verify FX is in zone file: `fx,_OwensAssets/bo7/sawblade_trap/sawblade_spinning_swirl`
- Check that `.efx` file exists in `share\raw\fx\_OwensAssets\bo7\sawblade_trap\`
- Recompile map (full compile, not just link)

### No sound
- Check that `sawblade_trap.csv` is in `share\raw\sound\aliases\`
- Verify `.szc` file has the sound alias entry
- Make sure all `.wav` files are in `sound_assets\_OwensAssets\bo7\sawblade_trap\`
- Recompile map with sound

## Credits

- **Treyarch:** Custom models, animations, FX, and sounds
- **Activision:** Custom GSC implementation for BO3 (developed with assistance from generative AI)
- **M5_Prodigy:** Testing 

## Development Note

**No credit to me required in your map** This trap was created primarily through AI assistance, so I dont feel i deserve any credit for it - my contribution was mainly porting the models from BO7 and making sure everything worked correctly. Feel free to use this in your maps however you wish.

## Support

For issues, questions, or support, check the release thread or contact the author.

## License

Free to use in your custom zombies maps. Credit is not required.

---

**Version:** 1.0
**Compatible with:** Call of Duty: Black Ops III Mod Tools
**Last Updated:** December 2025
