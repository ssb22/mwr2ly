#!/usr/bin/env python
# (should work in either Python 2 or Python 3)

# Add depth to MIDI file v1.2, Silas S. Brown.
# Used some code from an old version of
# Python Midi Package by Max M.

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Where to find history:
# on GitHub at https://github.com/ssb22/mwr2ly
# and on GitLab at https://gitlab.com/ssb22/mwr2ly
# and on BitBucket https://bitbucket.org/ssb22/mwr2ly
# and at https://gitlab.developers.cam.ac.uk/ssb22/mwr2ly
# and in China: git clone https://gitee.com/ssb22/mwr2ly

import sys
patch_map = list(range(128))
if "--cdp-130" in sys.argv:
    # Patch changes for Casio CDP-130
    patch_map = [0,1,2,3,4,3,5,5,6,6,6,6,6,6,6,6,9,9,9,8,9,9,9,9,5,5,5,5,5,5,5,5,0,0,0,0,0,0,0,0,7,7,7,7,7,5,6,0,7,7,7,7,7,7,7,7,9,9,9,9,9,9,9,9,9,9,9,9,7,7,7,7,7,7,7,7,7,7,7,7,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,5,5,5,5,6,9,7,7,6,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
    # and on channel 10: available keynums are 33 and 34 (Metronome Click and Metronome Bell), 75, 78 and 80 (claves, mute cuica, mute triangle: these are sounded by the user interface); other keys are silent
    sys.argv.remove("--cdp-130")

reverb_by_patch = [
0x70,0x70,0x70,0x70,    0x70,0x70,0x70,0x70,
0x70,0x70,0x70,0x70,    0x70,0x70,0x70,0x70,
0x00,0x00,0x7D,0x00,    0x00,0x00,0x00,0x00,
0x00,0x00,0x00,0x00,    0x00,0x00,0x00,0x00,
0x00,0x00,0x00,0x00,    0x00,0x00,0x00,0x00,
0x44,0x44,0x44,0x64,    0x44,0x44,0x44,0x70,
0x00,0x00,0x00,0x00,    0x70,0x70,0x70,0x70,
0x64,0x70,0x70,0x70,    0x64,0x64,0x64,0x64,
0x64,0x64,0x64,0x64,    0x64,0x64,0x64,0x64,
0x64,0x64,0x64,0x64,    0x64,0x64,0x64,0x64,
0x64,0x00,0x00,0x00,    0x00,0x00,0x00,0x00,
0x00,0x00,0x00,0x00,    0x00,0x00,0x00,0x00,
0x00,0x00,0x00,0x00,    0x00,0x00,0x00,0x00,
0x50,0x50,0x50,0x50,    0x00,0x00,0x00,0x00,
0x00,0x00,0x00,0x00,    0x00,0x00,0x00,0x00,
0x00,0x00,0x7D,0x00,    0x00,0x7D,0x60,0x7D]

pan_by_patch = [
0x40,0x40,0x40,0x40,    0x40,0x40,0x40,0x40,
0x40,0x30,0x40,0x32,    0x34,0x36,0x38,0x40,
0x40,0x40,0x40,0x40,    0x40,0x40,0x40,0x40,
0x40,0x40,0x40,0x40,    0x40,0x40,0x40,0x40,
0x40,0x40,0x40,0x40,    0x40,0x40,0x40,0x40,
0x3F,0x48,0x50,0x56,    0x40,0x40,0x4D,0x3C,
0x40,0x40,0x40,0x40,    0x40,0x40,0x40,0x40,
0x44,0x4C,0x4D,0x44,    0x3B,0x48,0x48,0x48,
0x40,0x41,0x42,0x43,    0x48,0x3B,0x40,0x39,
0x35,0x37,0x40,0x40,    0x40,0x38,0x40,0x40,
0x40,0x40,0x40,0x40,    0x40,0x40,0x40,0x40,
0x40,0x40,0x40,0x40,    0x40,0x40,0x40,0x40,
0x40,0x40,0x40,0x40,    0x40,0x40,0x40,0x40,
0x4A,0x4B,0x4C,0x4D,    0x40,0x40,0x40,0x40,
0x40,0x40,0x40,0x40,    0x40,0x40,0x40,0x40,
0x40,0x40,0x48,0x40,    0x40,0x40,0x40,0x40]

def B(s):
    if type("")==type(u""): return s.encode("utf-8") # Python 3
    else: return s # Python 2

try: from cStringIO import StringIO
except: # Python 3
    from io import BytesIO as StringIO
    unichr = chr
    def chr(x): return unichr(x).encode('latin1')
from struct import pack, unpack
def getNibbles(byte): return (byte >> 4 & 0xF, byte & 0xF)
def setNibbles(hiNibble, loNibble):
    return (hiNibble << 4) + loNibble
def readBew(value):
    return unpack('>%s' % {1:'B', 2:'H', 4:'L'}[len(value)], value)[0]
def writeBew(value, length):
    return pack('>%s' % {1:'B', 2:'H', 4:'L'}[length], value)
def readVar(value):
    sum = 0
    for byte in unpack('%sB' % len(value), value):
        sum = (sum << 7) + (byte & 0x7F)
        if not 0x80 & byte: break 
    return sum
def varLen(value):
    if value <= 127:
        return 1
    elif value <= 16383:
        return 2
    elif value <= 2097151:
        return 3
    else:
        return 4
def writeVar(value):
    sevens = to_n_bits(value, varLen(value))
    for i in range(len(sevens)-1):
        sevens[i] = sevens[i] | 0x80
    return fromBytes(sevens)
def to_n_bits(value, length=1, nbits=7):
    bytes = [(value >> (i*nbits)) & 0x7F for i in range(length)]
    bytes.reverse()
    return bytes
def toBytes(value):
    return unpack('%sB' % len(value), value)
def fromBytes(value):
    if not value:
        return B('')
    return pack('%sB' % len(value), *value)
class RawOutstreamFile:
    def __init__(self, outfile=None):
        if not outfile: outfile = B('')
        self.buffer = StringIO()
        self.outfile = outfile
    def writeSlice(self, str_slice):
        self.buffer.write(str_slice)
    def writeBew(self, value, length=1):
        self.writeSlice(writeBew(value, length))
    def writeVarLen(self, value):
        var = self.writeSlice(writeVar(value))
    def write(self):
        if self.outfile:
            if type(self.outfile)==str:
                outfile = open(self.outfile, 'wb')
                outfile.write(self.getvalue())
                outfile.close()
            else:
                self.outfile.write(self.getvalue())
    def getvalue(self):
        return self.buffer.getvalue()
NOTE_OFF = 0x80
NOTE_ON = 0x90
AFTERTOUCH = 0xA0
CONTINUOUS_CONTROLLER = 0xB0 
PATCH_CHANGE = 0xC0
CHANNEL_PRESSURE = 0xD0
PITCH_BEND = 0xE0
BANK_SELECT = 0x00
MODULATION_WHEEL = 0x01
BREATH_CONTROLLER = 0x02
FOOT_CONTROLLER = 0x04
PORTAMENTO_TIME = 0x05
DATA_ENTRY = 0x06
CHANNEL_VOLUME = 0x07
BALANCE = 0x08
PAN = 0x0A
EXPRESSION_CONTROLLER = 0x0B
EFFECT_CONTROL_1 = 0x0C
EFFECT_CONTROL_2 = 0x0D
GEN_PURPOSE_CONTROLLER_1 = 0x10
GEN_PURPOSE_CONTROLLER_2 = 0x11
GEN_PURPOSE_CONTROLLER_3 = 0x12
GEN_PURPOSE_CONTROLLER_4 = 0x13
BANK_SELECT = 0x20
MODULATION_WHEEL = 0x21
BREATH_CONTROLLER = 0x22
FOOT_CONTROLLER = 0x24
PORTAMENTO_TIME = 0x25
DATA_ENTRY = 0x26
CHANNEL_VOLUME = 0x27
BALANCE = 0x28
PAN = 0x2A
EXPRESSION_CONTROLLER = 0x2B
EFFECT_CONTROL_1 = 0x2C
EFFECT_CONTROL_2 = 0x2D
GENERAL_PURPOSE_CONTROLLER_1 = 0x30
GENERAL_PURPOSE_CONTROLLER_2 = 0x31
GENERAL_PURPOSE_CONTROLLER_3 = 0x32
GENERAL_PURPOSE_CONTROLLER_4 = 0x33
SUSTAIN_ONOFF = 0x40
PORTAMENTO_ONOFF = 0x41
SOSTENUTO_ONOFF = 0x42
SOFT_PEDAL_ONOFF = 0x43
LEGATO_ONOFF = 0x44
HOLD_2_ONOFF = 0x45
SOUND_CONTROLLER_1 = 0x46                  
SOUND_CONTROLLER_2 = 0x47                  
SOUND_CONTROLLER_3 = 0x48                  
SOUND_CONTROLLER_4 = 0x49                  
SOUND_CONTROLLER_5 = 0x4A                  
SOUND_CONTROLLER_7 = 0x4C                  
SOUND_CONTROLLER_8 = 0x4D                  
SOUND_CONTROLLER_9 = 0x4E                  
SOUND_CONTROLLER_10 = 0x4F                 
GENERAL_PURPOSE_CONTROLLER_5 = 0x50
GENERAL_PURPOSE_CONTROLLER_6 = 0x51
GENERAL_PURPOSE_CONTROLLER_7 = 0x52
GENERAL_PURPOSE_CONTROLLER_8 = 0x53
PORTAMENTO_CONTROL = 0x54                  
EFFECTS_1 = 0x5B                           
EFFECTS_2 = 0x5C                           
EFFECTS_3 = 0x5D                           
EFFECTS_4 = 0x5E                           
EFFECTS_5 = 0x5F                           
DATA_INCREMENT = 0x60                      
DATA_DECREMENT = 0x61                      
NON_REGISTERED_PARAMETER_NUMBER = 0x62     
NON_REGISTERED_PARAMETER_NUMBER = 0x63     
REGISTERED_PARAMETER_NUMBER = 0x64         
REGISTERED_PARAMETER_NUMBER = 0x65         
ALL_SOUND_OFF = 0x78
RESET_ALL_CONTROLLERS = 0x79
LOCAL_CONTROL_ONOFF = 0x7A
ALL_NOTES_OFF = 0x7B
OMNI_MODE_OFF = 0x7C          
OMNI_MODE_ON = 0x7D           
MONO_MODE_ON = 0x7E           
POLY_MODE_ON = 0x7F           
SYSTEM_EXCLUSIVE = 0xF0
MTC = 0xF1 
SONG_POSITION_POINTER = 0xF2
SONG_SELECT = 0xF3
TUNING_REQUEST = 0xF6
END_OFF_EXCLUSIVE = 0xF7 
SEQUENCE_NUMBER = 0x00      
TEXT            = 0x01      
COPYRIGHT       = 0x02      
SEQUENCE_NAME   = 0x03      
INSTRUMENT_NAME = 0x04      
LYRIC           = 0x05      
MARKER          = 0x06      
CUEPOINT        = 0x07      
PROGRAM_NAME    = 0x08      
DEVICE_NAME     = 0x09      
MIDI_CH_PREFIX  = 0x20      
MIDI_PORT       = 0x21      
END_OF_TRACK    = 0x2F      
TEMPO           = 0x51      
SMTP_OFFSET     = 0x54      
TIME_SIGNATURE  = 0x58      
KEY_SIGNATURE   = 0x59      
SPECIFIC        = 0x7F      
FILE_HEADER     = B('MThd')
TRACK_HEADER    = B('MTrk')
TIMING_CLOCK   = 0xF8
SONG_START     = 0xFA
SONG_CONTINUE  = 0xFB
SONG_STOP      = 0xFC
ACTIVE_SENSING = 0xFE
SYSTEM_RESET   = 0xFF
META_EVENT     = 0xFF
def is_status(byte):
    return (byte & 0x80) == 0x80 
class MidiOutFile:
    def update_time(self, new_time=0, relative=1):
        if relative:
            self._relative_time = new_time
            self._absolute_time += new_time
        else:
            self._relative_time = new_time - self._absolute_time
            self._absolute_time = new_time
    def reset_time(self):
        self._relative_time = 0
        self._absolute_time = 0
    def rel_time(self):
        return self._relative_time
    def abs_time(self):
        return self._absolute_time
    def reset_run_stat(self):
        self._running_status = None
    def set_run_stat(self, new_status):
        self._running_status = new_status
    def get_run_stat(self):
        return self._running_status
    def set_current_track(self, new_track):
        self._current_track = new_track
    def get_current_track(self):
        return self._current_track
    def __init__(self, raw_out=None):
        if not raw_out: raw_out = B('')
        self.raw_out = RawOutstreamFile(raw_out)
        self._absolute_time = 0
        self._relative_time = 0
        self._current_track = 0
        self._running_status = None
    def write(self):
        self.raw_out.write()
    def event_slice(self, slc):
        trk = self._current_track_buffer
        trk.writeVarLen(self.rel_time())
        trk.writeSlice(slc)
    def note_on(self, channel=0, note=0x40, velocity=0x40):
        slc = fromBytes([NOTE_ON + channel, note, velocity])
        self.event_slice(slc)
    def note_off(self, channel=0, note=0x40, velocity=0x40):
        slc = fromBytes([NOTE_OFF + channel, note, velocity])
        self.event_slice(slc)
    def aftertouch(self, channel=0, note=0x40, velocity=0x40):
        slc = fromBytes([AFTERTOUCH + channel, note, velocity])
        self.event_slice(slc)
    def continuous_controller(self, channel, controller, value):
        slc = fromBytes([CONTINUOUS_CONTROLLER + channel, controller, value])
        self.event_slice(slc)
    def patch_change(self, channel, patch):
        slc = fromBytes([PATCH_CHANGE + channel, patch])
        self.event_slice(slc)
    def channel_pressure(self, channel, pressure):
        slc = fromBytes([CHANNEL_PRESSURE + channel, pressure])
        self.event_slice(slc)
    def pitch_bend(self, channel, value):
        msb = (value>>7) & 0xFF
        lsb = value & 0xFF
        slc = fromBytes([PITCH_BEND + channel, msb, lsb])
        self.event_slice(slc)
    def sysex_event(self, data):
        sysex_len = writeVar(len(data)+1)
        self.event_slice(chr(SYSTEM_EXCLUSIVE) + sysex_len + data + chr(END_OFF_EXCLUSIVE))
    def midi_time_code(self, msg_type, values):
        value = (msg_type<<4) + values
        self.event_slice(fromBytes([MIDI_TIME_CODE, value]))
    def song_position_pointer(self, value):
        lsb = (value & 0x7F)
        msb = (value >> 7) & 0x7F
        self.event_slice(fromBytes([SONG_POSITION_POINTER, lsb, msb]))
    def song_select(self, songNumber):
        self.event_slice(fromBytes([SONG_SELECT, songNumber]))
    def tuning_request(self):
        self.event_slice(chr(TUNING_REQUEST))
    def header(self, format=0, nTracks=1, division=96):
        raw = self.raw_out
        raw.writeSlice(FILE_HEADER)
        bew = raw.writeBew
        bew(6, 4) 
        bew(format, 2)
        bew(nTracks, 2)
        bew(division, 2)
    def eof(self):
        self.write()
    def meta_slice(self, meta_type, data_slice):
        "Writes a meta event"
        slc = fromBytes([META_EVENT, meta_type]) + \
                         writeVar(len(data_slice)) +  data_slice
        self.event_slice(slc)
    def meta_event(self, meta_type, data):
        self.meta_slice(meta_type, fromBytes(data))
    def start_of_track(self, n_track=0):
        self._current_track_buffer = RawOutstreamFile()
        self.reset_time()
        self._current_track += 1
    def end_of_track(self):
        raw = self.raw_out
        raw.writeSlice(TRACK_HEADER)
        track_data = self._current_track_buffer.getvalue()
        eot_slice = writeVar(self.rel_time()) + fromBytes([META_EVENT, END_OF_TRACK, 0])
        raw.writeBew(len(track_data)+len(eot_slice), 4)
        raw.writeSlice(track_data)
        raw.writeSlice(eot_slice)
    def sequence_number(self, value):
        self.meta_slice(meta_type, writeBew(value, 2))
    def text(self, text):
        self.meta_slice(TEXT, text)
    def copyright(self, text):
        self.meta_slice(COPYRIGHT, text)
    def sequence_name(self, text):
        self.meta_slice(SEQUENCE_NAME, text)
    def instrument_name(self, text):
        self.meta_slice(INSTRUMENT_NAME, text)
    def lyric(self, text):
        self.meta_slice(LYRIC, text)
    def marker(self, text):
        self.meta_slice(MARKER, text)
    def cuepoint(self, text):
        self.meta_slice(CUEPOINT, text)
    def program_name(self,progname): pass
    def device_name(self,devicename): pass
    def midi_ch_prefix(self, channel):
        self.meta_slice(MIDI_CH_PREFIX, chr(channel))
    def midi_port(self, value):
        self.meta_slice(MIDI_CH_PREFIX, chr(value))
    def tempo(self, value):
        hb, mb, lb = (value>>16 & 0xff), (value>>8 & 0xff), (value & 0xff)
        self.meta_slice(TEMPO, fromBytes([hb, mb, lb]))
    def smtp_offset(self, hour, minute, second, frame, framePart):
        self.meta_slice(SMTP_OFFSET, fromBytes([hour, minute, second, frame, framePart]))
    def time_signature(self, nn, dd, cc, bb):
        self.meta_slice(TIME_SIGNATURE, fromBytes([nn, dd, cc, bb]))
    def key_signature(self, sf, mi):
        self.meta_slice(KEY_SIGNATURE, fromBytes([sf, mi]))
    def sequencer_specific(self, data):
        self.meta_slice(SPECIFIC, fromBytes(data))
class RawInstreamFile:
    def __init__(self, infile=None):
        if infile:
            if type(infile)==str:
                infile = open(infile, 'rb')
                self.data = infile.read()
                infile.close()
            else:
                self.data = infile.read()
        else: self.data = B('')
        self.cursor = 0
    def setData(self, data=None):
        if not data: data = B('')
        self.data = data
    def setCursor(self, position=0):
        self.cursor = position
    def getCursor(self):
        return self.cursor
    def moveCursor(self, relative_position=0):
        self.cursor += relative_position
    def nextSlice(self, length, move_cursor=1):
        c = self.cursor
        slc = self.data[c:c+length]
        if move_cursor:
            self.moveCursor(length)
        return slc
    def readBew(self, n_bytes=1, move_cursor=1):
        return readBew(self.nextSlice(n_bytes, move_cursor))
    def readVarLen(self):
        MAX_VARLEN = 4 
        var = readVar(self.nextSlice(MAX_VARLEN, 0))
        self.moveCursor(varLen(var))
        return var
class EventDispatcher:
    def __init__(self, outstream):
        self.outstream = outstream
        self.convert_zero_velocity = 1
        self.dispatch_continuos_controllers = 1 
        self.dispatch_meta_events = 1
    def header(self, format, nTracks, division):
        self.outstream.header(format, nTracks, division)
    def start_of_track(self, current_track):
        self.outstream.set_current_track(current_track)
        self.outstream.start_of_track(current_track)
    def sysex_event(self, data):
        self.outstream.sysex_event(data)
    def eof(self):
        self.outstream.eof()
    def update_time(self, new_time=0, relative=1):
        self.outstream.update_time(new_time, relative)
    def reset_time(self):
        self.outstream.reset_time()
    def channel_messages(self, hi_nible, channel, data):
        stream = self.outstream
        data = toBytes(data)
        if (NOTE_ON & 0xF0) == hi_nible:
            note, velocity = data
            if velocity==0 and self.convert_zero_velocity:
                stream.note_off(channel, note, 0x40)
            else:
                stream.note_on(channel, note, velocity)
        elif (NOTE_OFF & 0xF0) == hi_nible:
            note, velocity = data
            stream.note_off(channel, note, velocity)
        elif (AFTERTOUCH & 0xF0) == hi_nible:
            note, velocity = data
            stream.aftertouch(channel, note, velocity)
        elif (CONTINUOUS_CONTROLLER & 0xF0) == hi_nible:
            controller, value = data
            if self.dispatch_continuos_controllers:
                self.continuous_controllers(channel, controller, value)
            else:
                stream.continuous_controller(channel, controller, value)
        elif (PATCH_CHANGE & 0xF0) == hi_nible:
            program = data[0]
            stream.patch_change(channel, program)
        elif (CHANNEL_PRESSURE & 0xF0) == hi_nible:
            pressure = data[0]
            stream.channel_pressure(channel, pressure)
        elif (PITCH_BEND & 0xF0) == hi_nible:
            hibyte, lobyte = data
            value = (hibyte<<7) + lobyte
            stream.pitch_bend(channel, value)
        else: raise Exception('Illegal channel message')
    def continuous_controllers(self, channel, controller, value):
        stream = self.outstream
        stream.continuous_controller(channel, controller, value)
    def system_commons(self, common_type, common_data):
        stream = self.outstream
        if common_type == MTC:
            data = readBew(common_data)
            msg_type = (data & 0x07) >> 4
            values = (data & 0x0F)
            stream.midi_time_code(msg_type, values)
        elif common_type == SONG_POSITION_POINTER:
            hibyte, lobyte = toBytes(common_data)
            value = (hibyte<<7) + lobyte
            stream.song_position_pointer(value)
        elif common_type == SONG_SELECT:
            data = readBew(common_data)
            stream.song_select(data)
        elif common_type == TUNING_REQUEST:
            stream.tuning_request(time=None)
    def meta_events(self, meta_type, data):
        stream = self.outstream
        if meta_type == SEQUENCE_NUMBER:
            number = readBew(data)
            stream.sequence_number(number)
        elif meta_type == TEXT:
            stream.text(data)
        elif meta_type == COPYRIGHT:
            stream.copyright(data)
        elif meta_type == SEQUENCE_NAME:
            stream.sequence_name(data)
        elif meta_type == INSTRUMENT_NAME:
            stream.instrument_name(data)
        elif meta_type == LYRIC:
            stream.lyric(data)
        elif meta_type == MARKER:
            stream.marker(data)
        elif meta_type == CUEPOINT:
            stream.cuepoint(data)
        elif meta_type == PROGRAM_NAME:
            stream.program_name(data)
        elif meta_type == DEVICE_NAME:
            stream.device_name(data)
        elif meta_type == MIDI_CH_PREFIX:
            channel = readBew(data)
            stream.midi_ch_prefix(channel)
        elif meta_type == MIDI_PORT:
            port = readBew(data)
            stream.midi_port(port)
        elif meta_type == END_OF_TRACK:
            stream.end_of_track()
        elif meta_type == TEMPO:
            b1, b2, b3 = toBytes(data)
            stream.tempo((b1<<16) + (b2<<8) + b3)
        elif meta_type == SMTP_OFFSET:
            hour, minute, second, frame, framePart = toBytes(data)
            stream.smtp_offset(
                    hour, minute, second, frame, framePart)
        elif meta_type == TIME_SIGNATURE:
            nn, dd, cc, bb = toBytes(data)
            stream.time_signature(nn, dd, cc, bb)
        elif meta_type == KEY_SIGNATURE:
            sf, mi = toBytes(data)
            stream.key_signature(sf, mi)
        elif meta_type == SPECIFIC:
            meta_data = toBytes(data)
            stream.sequencer_specific(meta_data)
        else: 
            meta_data = toBytes(data)
            stream.meta_event(meta_type, meta_data)
class MidiFileParser:
    def __init__(self, raw_in, outstream):
        self.raw_in = raw_in
        self.dispatch = EventDispatcher(outstream)
        self._running_status = None
    def parseMThdChunk(self):
        raw_in = self.raw_in
        header_chunk_type = raw_in.nextSlice(4)
        header_chunk_zise = raw_in.readBew(4)
        if header_chunk_type != FILE_HEADER:
            raise Exception("Invalid MIDI file")
        self.format = raw_in.readBew(2)
        self.nTracks = raw_in.readBew(2)
        self.division = raw_in.readBew(2)
        if header_chunk_zise > 6:
            raw_in.moveCursor(header_chunk_zise-6)
        self.dispatch.header(self.format, self.nTracks, self.division)
    def parseMTrkChunk(self):
        self.dispatch.reset_time()
        dispatch = self.dispatch
        raw_in = self.raw_in
        dispatch.start_of_track(self._current_track)
        raw_in.moveCursor(4)
        tracklength = raw_in.readBew(4)
        track_endposition = raw_in.getCursor() + tracklength 
        while raw_in.getCursor() < track_endposition:
            time = raw_in.readVarLen()
            dispatch.update_time(time)
            peak_ahead = raw_in.readBew(move_cursor=0)
            if (peak_ahead & 0x80): 
                status = self._running_status = raw_in.readBew()
            else:
                status = self._running_status
            hi_nible, lo_nible = status & 0xF0, status & 0x0F
            if status == META_EVENT:
                meta_type = raw_in.readBew()
                meta_length = raw_in.readVarLen()
                meta_data = raw_in.nextSlice(meta_length)
                dispatch.meta_events(meta_type, meta_data)
            elif status == SYSTEM_EXCLUSIVE:
                sysex_length = raw_in.readVarLen()
                sysex_data = raw_in.nextSlice(sysex_length-1)
                if raw_in.readBew(move_cursor=0) == END_OFF_EXCLUSIVE:
                    eo_sysex = raw_in.readBew()
                dispatch.sysex_event(sysex_data)
            elif hi_nible == 0xF0: 
                data_sizes = {
                    MTC:1,
                    SONG_POSITION_POINTER:2,
                    SONG_SELECT:1,
                }
                data_size = data_sizes.get(hi_nible, 0)
                common_data = raw_in.nextSlice(data_size)
                common_type = lo_nible
                dispatch.system_common(common_type, common_data)
            else:
                data_sizes = {
                    PATCH_CHANGE:1,
                    CHANNEL_PRESSURE:1,
                    NOTE_OFF:2,
                    NOTE_ON:2,
                    AFTERTOUCH:2,
                    CONTINUOUS_CONTROLLER:2,
                    PITCH_BEND:2,
                }
                data_size = data_sizes.get(hi_nible, 0)
                channel_data = raw_in.nextSlice(data_size)
                event_type, channel = hi_nible, lo_nible
                dispatch.channel_messages(event_type, channel, channel_data)
    def parseMTrkChunks(self):
        for t in range(self.nTracks):
            self._current_track = t
            self.parseMTrkChunk() 
        self.dispatch.eof()
class MidiInFile:
    def __init__(self, outStream, infile=None):
        if not infile: infile = B('')
        self.raw_in = RawInstreamFile(infile)
        self.parser = MidiFileParser(self.raw_in, outStream)
    def read(self):
        p = self.parser
        p.parseMThdChunk()
        p.parseMTrkChunks()
    def setData(self, data=None):
        if not data: data = B('')
        self.raw_in.setData(data)

class MidiToMidi:
    def update_time(self, new_time=0, relative=1):
        self.midi.update_time(new_time,relative)
    def reset_time(self): self.midi.reset_time()
    def rel_time(self): return self.midi.rel_time()
    def abs_time(self): return self.midi.abs_time()
    def __init__(self,outfile):
        self.midi = MidiOutFile(outfile)
    def set_current_track(self, new_track):
        self.midi.set_current_track(new_track)
    def get_current_track(self):
        return self.midi.get_current_track()
    def channel_message(self, message_type, channel, data):
        self.midi.channel_message(message_type,channel,data)
    def note_on(self, channel=0, note=0x40, velocity=0x40):
        self.midi.note_on(channel,note,velocity)
    def note_off(self, channel=0, note=0x40, velocity=0x40):
        self.midi.note_off(channel, note, velocity)
    def aftertouch(self, channel=0, note=0x40, velocity=0x40):
        self.midi.aftertouch(channel, note, velocity)
    def continuous_controller(self, channel, controller, value):
        self.midi.continuous_controller(channel, controller, value)
    def patch_change(self, channel, patch):
        self.midi.patch_change(channel, patch_map[patch])
        # Introduce pan/reverb settings
        self.midi.update_time(0)
        self.midi.continuous_controller(channel,10,pan_by_patch[patch])
        self.midi.update_time(0)
        self.midi.continuous_controller(channel,91,reverb_by_patch[patch])
        # controller 93 if want chorus
        # e.g. for just flutes, clarinets and shamisen to be chorus:
        # self.midi.update_time(0)
        # if patch in [71,73,106]: self.midi.continuous_controller(channel,93,0x40)
        # else: self.midi.continuous_controller(channel,93,0)
    def channel_pressure(self, channel, pressure):
        self.midi.channel_pressure(channel, pressure)
    def pitch_bend(self, channel, value):
        self.midi.pitch_bend(channel, value)
    def sysex_event(self, data):
        self.midi.sysex_event(data)
    def song_position_pointer(self, value):
        self.midi.song_position_pointer(value)
    def song_select(self, songNumber):
        self.midi.song_select(songNumber)
    def tuning_request(self): self.midi.tuning_request()
    def midi_time_code(self, msg_type, values):
        self.midi.midi_time_code(msg_type,values)
    def header(self, format=0, nTracks=1, division=96):
        self.midi.header(format,nTracks,division)
    def eof(self): self.midi.eof()
    def start_of_track(self, n_track=0):
        self.midi.start_of_track(n_track)
    def end_of_track(self):
        self.midi.end_of_track()
    def meta_event(self, meta_type, data):
        self.midi.meta_event(meta_type,data)
    def sequence_number(self, value):
        self.midi.sequence_number(value)
    def text(self, text): self.midi.text(text)
    def copyright(self, text): self.midi.copyright(text)
    def sequence_name(self, text):
        self.midi.sequence_name(text)
    def instrument_name(self, text):
        self.midi.instrument_name(text)
    def lyric(self, text): self.midi.lyric(text)
    def marker(self, text): self.midi.marker(text)
    def cuepoint(self, text): self.midi.cuepoint(text)
    def midi_ch_prefix(self, channel):
        self.midi.midi_ch_prefix(channel)
    def midi_port(self, value):
        self.midi.midi_port(value)
    def tempo(self, value): self.midi.tempo(value)
    def smtp_offset(self, hour, minute, second, frame, framePart):
        self.midi.smtp_offset(hour, minute, second, frame, framePart)
    def time_signature(self, nn, dd, cc, bb):
        self.midi.time_signature(nn, dd, cc, bb)
    def key_signature(self, sf, mi):
        self.midi.key_signature(sf, mi)
    def sequencer_specific(self, data):
        self.midi.sequencer_specific(data)

if __name__ == '__main__':
    if len(sys.argv)<3:
        sys.stderr.write("Syntax: midi-add-depth [--cdp-130] infile|- outfile|-\n")
        sys.exit(1)
    if sys.argv[1]=='-':
        try: inF = sys.stdin.buffer
        except: inF = sys.stdin
    else: inF = open(sys.argv[1],"rb")
    if sys.argv[2]=='-':
        try: outF = sys.stdout.buffer
        except: outF = sys.stdout
    else: outF = open(sys.argv[2],"wb")
    MidiInFile(MidiToMidi(outF), inF).read()
