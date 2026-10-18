# Home Assistant Packages Library

Reusable, modular Home Assistant configuration packages for Project Pandora homelab.

## Overview

This directory (`ha-packages/`) is a library of Home Assistant packages that provide
reusable logic, integrations, and UI-controllable entities. It is mounted into the
Home Assistant container as `/config/packages/` and included via:

```yaml
homeassistant:
  packages: !include_dir_named packages
```

Each subdirectory is a self-contained **package** that groups related configuration
(sensors, helpers, automations, scripts, templates) into a single logical unit.

## Directory Structure

```
ha-packages/
├── AGENTS.md                    # This file - library documentation
├── mqtt_media_remote/           # Package: MQTT-based media remote control
│   ├── sensors.yaml             # MQTT sensors for state feedback
│   ├── helpers.yaml             # input_number, input_boolean UI helpers
│   ├── automations.yaml         # Automations connecting helpers to MQTT
│   ├── scripts.yaml             # Reusable media control scripts
│   ├── templates.yaml           # Template sensors for derived state
│   └── labels.yaml              # HA Labels + Group for UI organization
└── (future packages...)
```

## Architecture Principles

1. **Package-per-feature**: Each subdirectory is one logical feature/domain
2. **UI-first**: Provide scripts, input helpers, and sensors that are usable from the HA UI
3. **MQTT-centric**: External devices communicate via MQTT topics
4. **Declarative**: All configuration is YAML, version-controlled in this repo
5. **Documented**: Every package should have inline comments and this AGENTS.md updated

## Naming Conventions

### Packages
- Package directory name: `snake_case` (e.g., `mqtt_media_remote`)
- Used as prefix for unique_ids: `mqtt_media_remote_<instance>_<feature>`

### Entities
- Pattern: `<domain>.<instance>_<feature>`
- Instance identifies the target device (e.g., `desktop`, `laptop`, `livingroom_tv`)
- Feature describes the capability (e.g., `volume`, `playback_status`, `play_pause`)

### MQTT Topics
- Base pattern: `home/<instance>/<device-type>/<action>`
- State topics: `home/<instance>/<device-type>/state/<feature>`
- Command topics: `home/<instance>/<device-type>/<feature>/<action>`
- Request topics: `home/<instance>/<device-type>/<feature>/get`

Example for desktop media remote:
```
home/desktop/media-remote/state/volume          # Volume state (text: "Volume: 0.75")
home/desktop/media-remote/state/playback/status # Playback status
home/desktop/media-remote/state/sink/current    # Current audio sink (JSON)
home/desktop/media-remote/volume/set            # Set volume (payload: 0.0-1.0)
home/desktop/media-remote/volume/get            # Request volume state
home/desktop/media-remote/volume/up             # Volume up (payload: step %)
home/desktop/media-remote/volume/down           # Volume down (payload: step %)
home/desktop/media-remote/volume/mute           # Toggle mute
home/desktop/media-remote/playback/play-pause   # Toggle play/pause
home/desktop/media-remote/playback/next         # Next track
home/desktop/media-remote/playback/previous     # Previous track
home/desktop/media-remote/playback/stop         # Stop playback
home/desktop/media-remote/playback/status/get   # Request playback status
home/desktop/media-remote/sink/get              # Request current sink
home/desktop/media-remote/sink/list             # Request available sinks (optional)
home/desktop/media-remote/sink/set              # Set audio sink (payload: sink name)
```

## Package: mqtt_media_remote

Provides complete MQTT-based media remote control with UI integration.

### Entities Created

| Entity ID | Type | Description |
|-----------|------|-------------|
| `sensor.desktop_volume` | MQTT sensor | Volume level (0-100%) |
| `sensor.desktop_playback_status` | MQTT sensor | Playback status text |
| `sensor.desktop_current_sink` | MQTT sensor | Current audio output device |
| `sensor.desktop_volume_level` | Template sensor | Volume as ratio (0.0-1.0) |
| `binary_sensor.desktop_media_playing` | Template binary_sensor | True when media is playing |
| `input_number.desktop_volume` | Input number | Volume slider (0-100) |
| `input_boolean.desktop_muted` | Input boolean | Mute toggle |
| `script.desktop_play_pause` | Script | Toggle play/pause |
| `script.desktop_next_track` | Script | Next track |
| `script.desktop_previous_track` | Script | Previous track |
| `script.desktop_stop` | Script | Stop playback |
| `script.desktop_volume_up` | Script | Volume up 5% |
| `script.desktop_volume_down` | Script | Volume down 5% |
| `script.desktop_set_volume` | Script | Set volume (with parameter) |
| `script.desktop_toggle_mute` | Script | Toggle mute |
| `script.desktop_refresh_state` | Script | Request all states from device |

### Volume State Format

The media remote publishes volume as text: `Volume: 0.75` (0.0-1.0 range).
Parsing regex: `Volume:\s*([\d.]+).*`

### Adding a New Media Remote Instance

To add a media remote for a different device (e.g., `laptop`):

1. **Copy the package directory**:
   ```bash
   cp -r mqtt_media_remote mqtt_media_remote_laptop
   ```

2. **Update all topic prefixes** in every YAML file:
   - Replace `home/desktop/media-remote/` with `home/laptop/media-remote/`

3. **Update entity names and unique_ids**:
   - Replace `desktop` with `laptop` in all entity IDs
   - Replace `Desktop` with `Laptop` in display names
   - Update unique_id prefixes

4. **Update automation IDs** to be unique (e.g., `mqtt_media_remote_laptop_*`)

5. **Update labels** in `labels.yaml`:
   - Add a new label for the device (e.g., `laptop`)
   - Update the group entity name and entities list
   - Update entity label assignments in all files
   - **Keep the `ai_managed` label** on all entities

### Volume Parsing Template

The media remote sends volume as `Volume: 0.75`. To parse:

```jinja
{% set vol = value | regex_replace('Volume:\s*([\d.]+).*', '\1') | float %}
{{ (vol * 100) | round(0) }}  {# Convert to 0-100 #}
```

To send volume back (0-100 → 0.0-1.0):

```jinja
{{ (value | float / 100) | round(2) }}
```

## Common Patterns

### MQTT Sensor with Parsed Value

```yaml
mqtt:
  sensor:
    - name: "Device Feature"
      state_topic: "home/device/feature/state"
      value_template: "{{ value | some_filter }}"
      unit_of_measurement: "unit"
```

### Two-Way Sync (Helper <-> MQTT)

```yaml
# Helper -> MQTT
automation:
  - trigger:
      - platform: state
        entity_id: input_number.device_feature
    action:
      - service: mqtt.publish
        data:
          topic: "home/device/feature/set"
          payload: "{{ trigger.to_state.state }}"

# MQTT -> Helper
automation:
  - trigger:
      - platform: mqtt
        topic: "home/device/feature/state"
    action:
      - service: input_number.set_value
        target:
          entity_id: input_number.device_feature
        data:
          value: "{{ value | parse }}"
```

### State Request on Startup

```yaml
automation:
  - trigger:
      - platform: homeassistant
        event: start
    action:
      - service: mqtt.publish
        data:
          topic: "home/device/feature/get"
```

### Reusable Script with Parameters

```yaml
script:
  device_set_feature:
    fields:
      value:
        selector:
          number:
            min: 0
            max: 100
    sequence:
      - service: mqtt.publish
        data:
          topic: "home/device/feature/set"
          payload: "{{ value }}"
```

### Template Binary Sensor

```yaml
template:
  - binary_sensor:
      - name: "Device Active"
        state: "{{ states('sensor.device_status') == 'active' }}"
        device_class: running
```

## Labels and Groups

All entities in the `mqtt_media_remote` package are tagged with HA **Labels** for
easy filtering and organization in the UI:

| Label ID | Name | Icon | Description |
|----------|------|------|-------------|
| `media_remote` | Media Remote | mdi:remote | Media remote control entities |
| `desktop` | Desktop | mdi:desktop-tower | Desktop computer entities |
| `ai_managed` | AI Managed | mdi:robot | Entities managed by AI agent (opencode) |

### Defined Labels

Labels are defined in `mqtt_media_remote/labels.yaml` under `homeassistant.labels`.
These merge with any labels defined in your main `configuration.yaml`.

**Important**: The `ai_managed` label is applied to **every entity** created by this
library. Use this label to:
- Filter the UI to see all AI-managed entities
- Identify entities that can be safely modified or regenerated
- Distinguish library-managed entities from manually created ones
- Use in automations: `label_id: ai_managed`

### Label Assignment

Labels are assigned to entities via `homeassistant.customize` in `labels.yaml`.
This is used instead of inline `labels:` fields because not all integrations
(e.g., MQTT sensors) support the `labels` option in their YAML schema.

### Group Entity

A legacy `group.desktop_media_remote` entity is also created that contains all
media remote entities. This appears as a single card in the UI.

### Filtering by Label in the UI

1. Go to **Settings > Areas & Zones > Labels** to see all labels
2. Click a label to see all entities with that label
3. In dashboards, use the **By Label** section to add all labeled entities
4. Use labels in automations: `label_id: media_remote`

### Assigning Areas

Entities can also be assigned to **Areas** (e.g., "Office", "Desktop") via:
1. **Settings > Areas & Zones**
2. Select an entity and assign it to an area
3. Or use the entity's **Settings** dialog in any dashboard card

## UI Integration

All entities are designed to be used from the Home Assistant UI:

- **Input helpers** (`input_number`, `input_boolean`) appear as sliders/toggles
- **Scripts** appear as buttons and can be added to dashboards
- **Sensors** appear in entity cards and can be used in automations
- **Binary sensors** can be used in conditional cards
- **Labels** allow filtering and organizing entities by category
- **Group** (`group.desktop_media_remote`) provides a single-card view of all entities

### Recommended Dashboard Card

```yaml
type: entities
title: Desktop Media Remote
entities:
  - binary_sensor.desktop_media_playing
  - sensor.desktop_playback_status
  - input_number.desktop_volume
  - input_boolean.desktop_muted
  - sensor.desktop_current_sink
  - type: buttons
    entities:
      - script.desktop_previous_track
      - script.desktop_play_pause
      - script.desktop_next_track
      - script.desktop_stop
```

## Infrastructure Integration

### NixOS Module

The `ha-packages/` directory is mounted into the Home Assistant container via the
NixOS module at `services/home-assistant/default.nix`:

```nix
volumes = [
  "${./ha-packages}:/config/packages:ro"
];
```

### Deployment

Changes to this directory are deployed by:
1. Committing changes to git
2. Rebuilding the NixOS configuration: `nixos-rebuild switch`
3. The new files are mounted read-only into the HA container
4. Home Assistant picks up package changes on restart or via Developer Tools > YAML > Reload

## Future Expansion Ideas

### Planned Packages

- `mqtt_sensor_hub` - Generic MQTT sensor aggregation
- `presence_detection` - Device presence via MQTT/network
- `notification_router` - Smart notification routing
- `energy_monitoring` - Power monitoring and alerts
- `climate_control` - HVAC automation logic
- `media_player_bridge` - Bridge MQTT media remotes to HA media_player

### Planned Features for mqtt_media_remote

- [ ] Sink selection dropdown (requires `sink/list` and `sink/set` topics)
- [ ] Media position/duration tracking
- [ ] Playlist/track info display
- [ ] MQTT media_player entity for native HA media card
- [ ] Volume ramp (gradual volume changes)
- [ ] Preset volume levels (quick buttons)

## Troubleshooting

### Package Not Loading

1. Check that the directory is mounted: `docker exec home-assistant-app ls /config/packages/`
2. Check HA logs: `docker logs home-assistant-app`
3. Verify YAML syntax: Developer Tools > YAML > Check Configuration

### "Setup failed for 'input_boolean'/'input_number': Invalid config"

This usually means there's a **duplicate definition** in your main `configuration.yaml`.
The package defines these entities, so remove any existing definitions from your main config:

```yaml
# REMOVE these from configuration.yaml - they are now in the package:
# input_number:
#   desktop_volume: ...
# input_boolean:
#   desktop_muted: ...
# mqtt:
#   sensor: ...
# automation: ...
```

Keep only in `configuration.yaml`:
```yaml
homeassistant:
  packages: !include_dir_named packages
```

### Template Error: "'value' is undefined"

This happens when an MQTT sensor renders its template before receiving any message.
All templates in this package include `| default(...)` filters to handle this.
If you add new templates, always use defaults:

```jinja
{{ value | default('fallback') | float(0) }}
```

### MQTT Topics Not Working

1. Verify MQTT broker connection in HA: Settings > Devices & Services > MQTT
2. Use MQTT Explorer or `mosquitto_sub` to verify topics:
   ```bash
   mosquitto_sub -h mqtt.emdecloud.de -t 'home/desktop/#' -v
   ```
3. Check topic spelling matches exactly (case-sensitive)

### Volume Parsing Issues

If the volume sensor shows `unknown`:
1. Check the raw MQTT payload format
2. Adjust the regex in `value_template`
3. Test with: Developer Tools > Template

## References

- [Home Assistant Packages](https://www.home-assistant.io/docs/configuration/packages/)
- [MQTT Sensor](https://www.home-assistant.io/integrations/mqtt/#sensor)
- [MQTT Script](https://www.home-assistant.io/integrations/script/)
- [Template Integration](https://www.home-assistant.io/integrations/template/)
- [MQTT Media Player](https://www.home-assistant.io/integrations/mqtt/#media-player)
