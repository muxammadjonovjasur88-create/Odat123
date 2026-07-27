import wave
import struct
import math
import os
import shutil

def generate_tone(filename, frequency, duration, volume=0.5, modulation_freq=0):
    sample_rate = 44100
    num_samples = int(sample_rate * duration)
    
    with wave.open(filename, 'w') as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(sample_rate)
        
        for i in range(num_samples):
            time = i / sample_rate
            
            # Amplitude envelope (fade in/out to avoid clicks)
            env = 1.0
            if time < 0.05: env = time / 0.05
            elif time > duration - 0.05: env = (duration - time) / 0.05
            
            # Apply modulation (for a pulsing effect)
            if modulation_freq > 0:
                mod = 0.5 * (1.0 + math.sin(2 * math.pi * modulation_freq * time))
                env *= mod
            
            value = int(volume * env * 32767.0 * math.sin(2 * math.pi * frequency * time))
            data = struct.pack('<h', value)
            wav_file.writeframesraw(data)

os.makedirs('assets/sounds', exist_ok=True)
os.makedirs('android/app/src/main/res/raw', exist_ok=True)

# alarm_soft.wav: A gentle, lower frequency chime
generate_tone('assets/sounds/alarm_soft.wav', frequency=440.0, duration=3.0, volume=0.3, modulation_freq=2.0)
# alarm_loud.wav: A higher frequency, pulsing alert
generate_tone('assets/sounds/alarm_loud.wav', frequency=1000.0, duration=3.0, volume=0.8, modulation_freq=5.0)

# copy them to res/raw
shutil.copy('assets/sounds/alarm_soft.wav', 'android/app/src/main/res/raw/alarm_soft.wav')
shutil.copy('assets/sounds/alarm_loud.wav', 'android/app/src/main/res/raw/alarm_loud.wav')

print("Sounds generated.")
