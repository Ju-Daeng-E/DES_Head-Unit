#!/usr/bin/env python3
"""
Generate Plymouth script with explicit frame loading
Plymouth script language doesn't support string formatting,
so we generate the script with all frame loads hardcoded
"""

def generate_plymouth_script(frame_count=210, fps=30):
    script = f'''# DES Cockpit Plymouth Boot Animation Script
# Ferrari logo video animation (7 seconds @ {fps}fps = {frame_count} frames)
# Auto-generated script - DO NOT EDIT MANUALLY
# Uses on-demand frame loading for faster startup

# Animation configuration
frame_count = {frame_count};
animation_fps = {fps};

# Frame cache - load frames on demand
frame_cache = [];
frame_loaded = [];

# Initialize flags
for (i = 0; i < frame_count; i++) {{
    frame_loaded[i] = 0;
}}

'''

    # Generate frame loading function for each frame
    script += '# Frame loading functions\n'
    for i in range(frame_count):
        frame_filename = f"frame_{i:04d}.png"
        script += f'''fun load_frame_{i}() {{
    if (!frame_loaded[{i}]) {{
        frame_cache[{i}] = Image("{frame_filename}");
        frame_loaded[{i}] = 1;
    }}
    return frame_cache[{i}];
}}

'''

    script += '''
# Pre-load first few frames for smooth start
frame_cache[0] = Image("frame_0000.png");
frame_loaded[0] = 1;

# Create sprite for animation
animation_sprite = Sprite();
animation_sprite.SetImage(frame_cache[0]);

# Center position calculation
screen_width = Window.GetWidth();
screen_height = Window.GetHeight();

# Timer for frame updates
elapsed_time = 0;
current_frame_index = 0;
last_frame_index = 0;

# Refresh callback - update animation frame
fun refresh_callback() {
    # Calculate which frame to display based on elapsed time
    # Plymouth refresh rate is ~50Hz, so we update frame index accordingly
    target_frame = Math.Int(elapsed_time * animation_fps);

    # Loop animation
    current_frame_index = target_frame % frame_count;

    # Only update if frame changed
    if (current_frame_index != last_frame_index) {
'''

    # Add conditional frame loading calls
    for i in range(frame_count):
        script += f'        if (current_frame_index == {i}) {{ animation_sprite.SetImage(load_frame_{i}()); }}\n'

    script += '''
        # Center the sprite
        if (frame_loaded[current_frame_index]) {
            frame_width = frame_cache[current_frame_index].GetWidth();
            frame_height = frame_cache[current_frame_index].GetHeight();

            pos_x = (screen_width - frame_width) / 2;
            pos_y = (screen_height - frame_height) / 2;

            animation_sprite.SetPosition(pos_x, pos_y, 100);
        }

        last_frame_index = current_frame_index;
    }

    # Increment time (refresh is called ~50 times per second)
    elapsed_time += 0.02;  # 20ms per refresh
}

Plymouth.SetRefreshFunction(refresh_callback);

# Progress bar callback - update boot progress
fun progress_callback(duration, progress) {
    # Optional: Can add progress indicator if needed
    # For now, just show the animation
}

Plymouth.SetBootProgressFunction(progress_callback);

# Message handler - hide boot messages for clean appearance
fun message_callback(text) {
    # Hide messages for clean boot animation
}

Plymouth.SetMessageFunction(message_callback);

# Display mode handlers
fun display_normal_callback() {
    # Normal display mode - continue animation
}

fun display_password_callback(prompt, bullets) {
    # Password prompt - pause animation and show prompt
    # (Not typically used during boot)
}

fun display_question_callback(prompt, entry) {
    # Question prompt - pause animation and show prompt
    # (Not typically used during boot)
}

Plymouth.SetDisplayNormalFunction(display_normal_callback);
Plymouth.SetDisplayPasswordFunction(display_password_callback);
Plymouth.SetDisplayQuestionFunction(display_question_callback);

# Quit callback - cleanup
fun quit_callback() {
    # Animation ends - cleanup sprites
    animation_sprite = NULL;
}

Plymouth.SetQuitFunction(quit_callback);
'''

    return script

if __name__ == "__main__":
    script_content = generate_plymouth_script(frame_count=210, fps=30)

    output_path = "plymouth/des-theme/des.script"
    with open(output_path, 'w') as f:
        f.write(script_content)

    print(f"Generated Plymouth script: {output_path}")
    print(f"Script size: {len(script_content)} bytes")
    print(f"Total frames: 210")
