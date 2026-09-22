"""Original synthesized game cues, with no third-party samples."""
import math,random,wave,struct
from pathlib import Path
RATE=24000
out=Path(__file__).resolve().parents[1]/'assets/audio';out.mkdir(parents=True,exist_ok=True)
def write(name,duration,sample):
 rng=random.Random(82);values=[sample(i/RATE,rng) for i in range(round(RATE*duration))]
 peak=max(abs(v) for v in values) or 1
 with wave.open(str(out/(name+'.wav')),'wb') as f:
  f.setnchannels(1);f.setsampwidth(2);f.setframerate(RATE)
  f.writeframes(b''.join(struct.pack('<h',round(v/peak*24500)) for v in values))
def tone(t,hz): return math.sin(2*math.pi*hz*t)
def note(t,f,length):
 return (tone(t,f)+0.35*tone(t,f*2)+0.12*tone(t,f*3))*min(1,t/0.012)*math.exp(-t*4/length)
notes=[146.83,220,293.66,261.63,220,174.61,196,220]
def lobby(t,r):
 step=t%0.5;idx=int(t/0.5)%len(notes)
 lead=note(step,notes[idx]*2,.5)*.25
 pad=.10*(tone(t,146.83)+tone(t,220)+tone(t,293.66))*(.6+.4*math.sin(math.pi*t/16)**2)
 return (lead+pad+0.012*r.uniform(-1,1))*min(1,t/.04,(16-t)/.04)
def match(t,r):
 pulse=t%0.75
 heartbeat=math.sin(2*math.pi*(55*pulse+10*(1-math.exp(-pulse*16))))*math.exp(-pulse*15)
 drone=.11*tone(t,73.416)+.06*tone(t,77.78)+.04*tone(t,146.83)
 return (heartbeat*.24+drone)*min(1,t/.02,(12-t)/.02)
def dragon(t,r):
 env=math.sin(math.pi*min(1,t/2.5))**.65
 growl=tone(t,63+8*math.sin(t*8))+.4*tone(t,127)
 return (growl*.24+r.uniform(-1,1)*.16*(.4+.6*math.sin(t*15)**2))*env
write('lobby_harbor',16,lobby)
write('match_tension',12,match)
write('dragon_roar',2.5,dragon)
write('knife_impact',.6,lambda t,r:(r.uniform(-1,1)*math.exp(-t*52)+.7*tone(t,185)*math.exp(-t*17)+.2*tone(t,920)*math.exp(-t*25))*min(1,t/.002))
chord=[293.66,369.99,440,587.33,739.99,880]
def win(t,r):
 return sum(note(t-i*.16,hz,1.6)*.18 for i,hz in enumerate(chord) if t>=i*.16)*min(1,(3-t)/.15)
write('victory_fanfare',3,win)
print('Created 5 original WAV files')
