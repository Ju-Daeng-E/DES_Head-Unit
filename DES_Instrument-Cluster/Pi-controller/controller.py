import time
from vehicles import PiRacerStandard
from gamepads import ShanWanGamepad
import multiprocessing as mp
from multiprocessing import shared_memory
import struct
import signal
import sys
import os

# setting control values
THROTTLE_MAX = 0.6
SHARED_MEM_SIZE = 4    # bytes: 1 int for drive mode

class SharedDriveMode:
    """Manages shared memory for drive mode between processes"""
    
    # Drive mode constants
    NEUTRAL = 0
    DRIVE = 1
    REVERSE = 2
    PARKING = 3
    
    MODE_NAMES = {
        "neutral": NEUTRAL,
        "drive": DRIVE,
        "reverse": REVERSE,
        "parking": PARKING
    }
    
    def __init__(self, create=True):
        self.shm_name = 'piracer_drive_mode'
        
        if create:
            try:
                # Try to create new shared memory
                self.shm = shared_memory.SharedMemory(
                    create=True, 
                    size=SHARED_MEM_SIZE, 
                    name=self.shm_name
                )
                # Initialize with neutral mode
                self.write_mode(self.NEUTRAL)
            except FileExistsError:
                # If already exists, connect to existing
                self.shm = shared_memory.SharedMemory(name=self.shm_name)
        else:
            # Connect to existing shared memory
            self.shm = shared_memory.SharedMemory(name=self.shm_name)
    
    def write_mode(self, mode):
        """Write drive mode to shared memory
        0 = neutral, 1 = drive, 2 = reverse, 3 = parking
        """
        data = struct.pack('i', mode)
        self.shm.buf[:len(data)] = data
    
    def read_mode(self):
        """Read drive mode from shared memory"""
        data = struct.unpack('i', self.shm.buf[:SHARED_MEM_SIZE])
        return data[0]
    
    def get_mode_name(self, mode=None):
        """Get the name of the current or specified mode"""
        if mode is None:
            mode = self.read_mode()
        return self.MODE_NAMES.get(mode, "unknown")
    
    def cleanup(self):
        """Clean up shared memory"""
        try:
            self.shm.close()
            self.shm.unlink()
        except FileNotFoundError:
            pass      
  
def clear_line():
    """Clear the current line and return cursor to beginning"""
    print('\r' + ' ' * 80 + '\r', end='', flush=True)

def print_status(message):
    """Print status message with line clearing"""
    clear_line()
    print(message, flush=True)

def print_inline(message):
    """Print message on same line (overwriting previous)"""
    clear_line()
    print(message, end='', flush=True)
    """Initialize gamepad with error handling"""

#main loop
def main():
    try:
        # initailize gamepad object
        gamepad = ShanWanGamepad()
        print_status("initialized gamepad")
    except FileNotFoundError:
        print_status("error: can't find gamepad (/dev/input/js0)")
        exit()

    # initalize robot
    car = PiRacerStandard()
    # initialize Shared Memory
    sharedDriveMode = SharedDriveMode()

    try:
        drive_mode = "neutral"  # can be 'drive', 'reverse', 'neutral', 'parking'

        while True:
            pad_state = gamepad.read_data()

            # 1. steering control (left analog stick)
            steering_input = pad_state.analog_stick_left.x
            if steering_input is not None:
                car.set_steering_percent(steering_input)

            # 2. gear selection (button X: parking, button Y: reverse)
            if pad_state.button_x:  # button 2
                drive_mode = "parking"
            elif pad_state.button_a:
                drive_mode = "drive"
            elif pad_state.button_y:  # button 3
                drive_mode = "reverse"
            elif pad_state.button_b:
                drive_mode = "neutral"

            sharedDriveMode.write_mode(SharedDriveMode.MODE_NAMES.get(drive_mode))

            # 3. throttle control (right analog stick y, forward is negative on most gamepads)
            throttle_input = pad_state.analog_stick_right.y or 0.0
            # print_inline(f"Throttle Input: {throttle_input}\n")
            
            # Split the analog stick into two zones:
            # Top half (negative values): Drive forward
            # Bottom half (positive values): Reverse

            if throttle_input < 0.0:  # Bottom half - Reverse
                # Map from [-1.0, 0.0] to [0.0, 1.0] for drive intensity
                throttle_intensity = throttle_input * THROTTLE_MAX
                stick_direction = "backward"
            elif throttle_input > 0.0:  # # Top half - Drive  
                # Map from [0.0, 1.0] to [0.0, 1.0] for reverse intensity
                throttle_intensity = throttle_input * THROTTLE_MAX
                stick_direction = "forward"
            else:  # Dead center - Neutral
                throttle_intensity = 0.0
                stick_direction = "neutral"

# 4. apply throttle and gear logic with stick zones
            if drive_mode == "drive":
                if stick_direction == "forward":
                    car.set_throttle_percent(throttle_intensity)
                elif stick_direction == "backward":
                    car.set_throttle_percent(0.0)  # No reverse when in drive mode
                else:
                    car.set_throttle_percent(0.0)
            elif drive_mode == "reverse":
                if stick_direction == "backward":
                    car.set_throttle_percent(-throttle_intensity)
                elif stick_direction == "forward":
                    car.set_throttle_percent(0.0)  # No forward when in reverse mode
                else:
                    car.set_throttle_percent(0.0)
            elif drive_mode == "neutral":
                car.set_throttle_percent(0.0)
            elif drive_mode == "parking":
                car.set_throttle_percent(0.0)
                car.set_steering_percent(0.0)

            # for debugging
            print_inline(f"Steering: {steering_input:.2f}, Throttle: {throttle_intensity:.2f}, Mode: {drive_mode}")
    except KeyboardInterrupt:
        print_status("program stopped by user.")
    finally:
        # safe stop and reset steering
        print_status("safe stop and reset steering")
        car.set_throttle_percent(0.0)
        car.set_steering_percent(0.0)
        sharedDriveMode.cleanup()

if __name__ == "__main__":
    main()
