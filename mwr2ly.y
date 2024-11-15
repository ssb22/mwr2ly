
/*
   Manuscript Writer to Lilypond converter
   Version 1.31, (c) 2010-13,2015-'16,'19,'21,'24 Silas S. Brown
   
   This program uses btyacc (Backtracking YACC)
   To set up:
   1. Install package btyacc (or compile from source; on
      some systems e.g. Mac you have to remove -static
      from the Makefile of btyacc 3.0 before running make,
      plus with newer compilers add #include <string.h> to mstring.c)
   2. btyacc mwr2ly.y && g++ -Wno-write-strings y[._]tab.c -o mwr2ly
   
   If you can't get btyacc (and g++) or if you
   are on more limited hardware, you could also
   compile it with bison, but it won't work so
   well on more complex inputs (e.g. divisi):

   sed -e 's/\[YYVALID;\]//g' -e 's,//if-bison:,,' < mwr2ly.y | grep -v if-btyacc > mwr2ly2.y && bison mwr2ly2.y && gcc mwr2ly2.tab.c -o mwr2ly

   Note that not all of Manuscript Writer's commands are
   interpreted (in particular the high-level score layout
   and instrument names etc will need re-doing), and in some
   cases a TODO will be left in the Lilypond output file for
   your attention.

   Extensions to the Manuscript Writer language:
   1. Barlines can be represented by tabs as well as spaces
      (so you can work in a spreadsheet for example)
   2. You can embed some Lilypond commands into the MWR code:
      \repeat percent 4 {L16fgab}
      (\ starts a Lilypond command, { or newline ends it, } copied as-is)
      or use { to make rest of line a Lilypond literal:
      {R1*4 % TODO: set length back from 1 on next note
      however this is quite basic and might not always work properly,
      for example embedding Lilypond repeat markup inside tuplets will
      cause this program to lose track of where the end of the tuplet is

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

If you want to compare this code to old versions, history is
kept on GitHub at https://github.com/ssb22/mwr2ly
and on GitLab at https://gitlab.com/ssb22/mwr2ly
and on BitBucket https://bitbucket.org/ssb22/mwr2ly
and at https://gitlab.developers.cam.ac.uk/ssb22/mwr2ly
and in China: https://gitee.com/ssb22/mwr2ly
although some early ones are missing.

*/

%{
//#define YYDEBUG 1
// confuses some versions of btyacc, try:
#define YYDEBUG 0
#define YYDELETEVAL(x,y)
#define YYDELETEPOSN(x,y)
#define TRUE 1
  
#define YYERROR_VERBOSE 1
#define mystrcat(buf,str) if(strlen(buf)+strlen(str)<sizeof(buf)) strcat(buf,str)
#include <stdio.h>
#include <ctype.h>
#include <string.h>
#include <stdlib.h>
  int rests_are_skips = 0;
  int num_fullbar_rests = 0;
  char fullbar_rest_buf[9]; // should need 5 (R64.) as more complex cases not handled
  // print with " |\n"
  int suppressNextBarline=0;
  int last_int_value, needPling=0;
  int partOK; int clef=10;
  int shortScore=0;
  int transposition_to_be_played=0, transposition_level=0;
  int in_phrase=0; // if nested phrasing, inner could be tie (TODO or outer could be phrasemarks rather than slurs)
  char nextPartLetter='A', markupPos;
  int curLen=4,curOctave=2,lilyCurLen=0,lilyCurDots=0;
  int timeTop=4,timeBottom=4,inFirstTimeBar=0;
  int textBufPtr=0; char textBuf[200];
  void flush_fullbar_rests() { if(num_fullbar_rests) { fputs(fullbar_rest_buf,stdout);if(num_fullbar_rests>1)printf("*%d",num_fullbar_rests);puts(" |");num_fullbar_rests=0;} }
  void bufChar(int c) { if(textBufPtr<sizeof(textBuf)) textBuf[textBufPtr++]=c; }
  int need_to_open_phrase=0,inChord=0,hadRepeats=0;
  char *hasTenuto=NULL;
  int fitIn, tuplet_stop_after=0;
  int tempoBPM, wasDot;
  char lastNoteLetter; int staccato=0,numDots=0;
  char *last_accidental, *bow;
  char *barAccidentals[7]={"","","","","","",""};
  char *keysigAccidentals[7]={"","","","","","",""};
  char volBuf[100]={0};
  int overridden_lilypond_bar_numbering=0;
  const char* lilypond_inst_names[]={"acoustic grand", "bright acoustic", "electric grand", "honky-tonk", "electric piano 1", "electric piano 2", "harpsichord", "clav", "celesta", "glockenspiel", "music box", "vibraphone", "marimba", "xylophone", "tubular bells", "dulcimer", "drawbar organ", "percussive organ", "rock organ", "church organ", "reed organ", "accordion", "harmonica", "tango accordion", "acoustic guitar (nylon)", "acoustic guitar (steel)", "electric guitar (jazz)", "electric guitar (clean)", "electric guitar (muted)", "overdriven guitar", "distortion guitar", "guitar harmonics", "acoustic bass", "electric bass (finger)", "electric bass (pick)", "fretless bass", "slap bass 1", "slap bass 2", "synth bass 1", "synth bass 2", "violin", "viola", "cello", "contrabass", "tremolo strings", "pizzicato strings", "orchestral strings", "timpani", "string ensemble 1", "string ensemble 2", "synthstrings 1", "synthstrings 2", "choir aahs", "voice oohs", "synth voice", "orchestra hit", "trumpet", "trombone", "tuba", "muted trumpet", "french horn", "brass section", "synthbrass 1", "synthbrass 2", "soprano sax", "alto sax", "tenor sax", "baritone sax", "oboe", "english horn", "bassoon", "clarinet", "piccolo", "flute", "recorder", "pan flute", "blown bottle",
  "shakuhachi" /* misspelled skakuhachi in Lilypond 2.0.1; that was fixed in Lilypond CVS 2003-10 and well before 2009's 2.12.2 we targetted, but versions of mwr2ly before 1.162 (2016-09) used the wrong spelling because I'd landed on an old version of the Lilypond manual when searching for its MIDI string table, oops */ ,
  "whistle", "ocarina", "lead 1 (square)", "lead 2 (sawtooth)", "lead 3 (calliope)", "lead 4 (chiff)", "lead 5 (charang)", "lead 6 (voice)", "lead 7 (fifths)", "lead 8 (bass+lead)", "pad 1 (new age)", "pad 2 (warm)", "pad 3 (polysynth)", "pad 4 (choir)", "pad 5 (bowed)", "pad 6 (metallic)", "pad 7 (halo)", "pad 8 (sweep)", "fx 1 (rain)", "fx 2 (soundtrack)", "fx 3 (crystal)", "fx 4 (atmosphere)", "fx 5 (brightness)", "fx 6 (goblins)", "fx 7 (echoes)", "fx 8 (sci-fi)", "sitar", "banjo", "shamisen", "koto", "kalimba", "bagpipe", "fiddle", "shanai", "tinkle bell", "agogo", "steel drums", "woodblock", "taiko drum", "melodic tom", "synth drum", "reverse cymbal", "guitar fret noise", "breath noise", "seashore", "bird tweet", "telephone ring", "helicopter", "applause", "gunshot"};
  const char* positive_transpositions[]={"c'","b","bes","a","aes","g","ges","f","e","ees","d","des"}; // $P2 = concert Bb is printed as C = \transposition bes = \transpose bes c'
  const char* negative_transpositions[]={"c'","cis'","d'","dis'","e'","f'","fis'","g'","gis'","a'","ais'","b'"};

  int fills_bar() {
    int numBeats;
    if(numDots>1 || timeBottom%curLen || tuplet_stop_after) return 0; // don't bother with complex cases like that
    numBeats = timeBottom/curLen;
    if(numDots) {
      if(numBeats%2) return 0;
      numBeats += numBeats/2;
    }
    return numBeats==timeTop;
  }
  void close_part() {
    flush_fullbar_rests();
    while(transposition_level){printf("} "); transposition_level--;} // TODO some MWR files might propagate it into the next part
    if(!suppressNextBarline) printf("\\bar \"|.\" ");
    printf("}\n");
    if(in_phrase) {in_phrase=0; fprintf(stderr,"Warning: unterminated slur in part%c\n",nextPartLetter-1);}
  }
  
  int yylex();
  int yyerror(const char*);

  %}

%%

Start: input MaybeDoubleBarAtEnd MaybeEnd;
MaybeEnd: '@' MaybeIgnore | '%' MaybeIgnore | ;
MaybeIgnore: | MaybeIgnore Ignore;

input: /* empty */ | Bar | Bar Barline [YYVALID;] {if(inFirstTimeBar==2) inFirstTimeBar=3; else if(inFirstTimeBar==3) {inFirstTimeBar=0;puts("} }");}} input;

Bar: BarSetup BarInner {suppressNextBarline=0;} BarEnd;
BarSetup: /* empty */ | BarSetup BarSetupCommand;
BarEnd: /* empty */ | BarEnd BarEndCommand;
/* if-btyacc */ BarInner: BarVoice | {flush_fullbar_rests();printf("<< { "); lilyCurLen=0;} BarVoice ',' {flush_fullbar_rests();printf(" } \\\\ { ");lilyCurLen=0;} BarVoice {flush_fullbar_rests();printf(" } >> ");lilyCurLen=0;}; // TODO make sure time signature etc does not occur within a divisi structure (but careful if splitting some things to PreBarCommands, need to include len/8ve state changes and can overload the backtracker)
//if-bison:  BarInner: BarVoice MaybeVoice2;
//if-bison:  MaybeVoice2: | ',' {flush_fullbar_rests();printf(" %%{ TODO start divisi part %%} ");} BarVoice {flush_fullbar_rests();printf(" %%{ TODO end divisi part %%} ");};

BarVoice: CommandCanEndInt | CommandCanEndInt BarVoice;
BarVoice: CommandNoIntAtEnd TupletPoint;
TupletPoint: MaybeTuplet /* at end of bar, sets for next */ | MaybeTuplet BarVoice;

CommandNoIntAtEnd: {flush_fullbar_rests();} EmbeddedLilypond;
EmbeddedLilypond: '\\' {putchar('\\');} LyIgnorePrint EmbedLilypondEnd;
EmbedLilypondEnd: '{' {putchar('{'); hadRepeats=1;/*maybe it was a repeat command*/} | '\n' {putchar('\n');};
EmbeddedLilypond: '}' {putchar('}');};
EmbeddedLilypond: '{' LyIgnorePrintAll '\n';

BarSetupCommand: '$' '1' {flush_fullbar_rests();puts(" } \\alternative { { "); inFirstTimeBar=1;};
CommandNoIntAtEnd: CommandNoIntOrSetupCommand;
CommandCanEndInt: CommandEndIntOrSetupCommand;
CommandNoIntOrSetupCommand: Ignore;
CommandCanEndInt: Volume; /* because could get e.g. V>3; we put MaybeTuplet in it ourselves for the versions that are compatible with tuplets */
/* if-btyacc */ BarSetupCommand: CommandNoIntOrSetupCommand | CommandEndIntOrSetupCommand; BarEndCommand: CommandNoIntOrSetupCommand | CommandEndIntOrSetupCommand; /* TODO: bison equivalent? */
BarSetupCommand: '[' {flush_fullbar_rests();puts("\\repeat volta 2 {");hadRepeats=1;};
BarEndCommand: ']' {flush_fullbar_rests();if(inFirstTimeBar){inFirstTimeBar=2;puts("} {");} else puts("}"); suppressNextBarline=1;};
CommandNoIntOrSetupCommand: Comment
  | '"' LineIgnore '\n' /* shell commands etc */
  | '~' /* orientation */;
CommandEndIntOrSetupCommand:
    W Integer CommaIgnore /* width stuff */ 
  | H Integer CommaIgnore /* pixels per horiz unit */
  | Z Integer /* staff line size */
  | Y Integer MaybeSharp /* stave gap */
  | S Integer MaybeSharp /* start at stave/page no. */
  | M Integer /* margin */
  | I Integer CommaIgnore /* staves per system etc */
  | '/' Unsigned MaybeSlash | '*' Unsigned /* beaming division */
  | '|' Integer /* stem length */ ;
CommandNoIntOrSetupCommand: '$' X LineIgnore '\n' /* titles etc - TODO */
/* $x <fontNo>,<height>[,hoffset[T|A|C title/author/copyright]]text
   (if use T|A|C, hoffset becomes voffset - 2nd line of title etc) */
  | '$' A /* auto-dimensions */
  | '$' Q LineIgnore '\n' /* instrument name */
  | '$' ':' /* guaranteed to be ignored */
  /* TODO '$' V ignore all incl newline up to but not including next $ (lyrics or composers' note) */
  | '$' U LineIgnore '\n' /* include file */
  | '$' '$' CharIgnore /* conditional compilation (A-Z toggles, a-z..a-z ignores if unset; 1 and 2=is/isn't first part) */ | '$' K CharIgnore /* conditional vars input from keyb (Y or N) */
  | '$' '-' { shortScore = 1; };
CommandEndIntOrSetupCommand:
    '$' D Unsigned ',' InstDefChars /* instrument definition */
  | '$' O Integer CommaIgnore /* 8va params */
  | '$' T Integer CommaIgnore /* timebar params */
  | '$' H Integer /* timebar height */
  | '$' N Integer /* timesig font */
  | '$' I InstrumentCommand
  | '$' M Integer CommaIgnore /* magnification */
  | '$' L Integer /* obsolete bar-length command */
  | '$' S Integer /* start-of-stave gap */
  | '$' G Integer /* key signature alignment gap */
  | '$' J Integer CommaIgnore /* text justification */ 
  | '$' Y Integer /* bar compression constant */
  | '$' '5' Unsigned /* number of stave lines */
  | '$' E Integer /* espressivo value */ ;
InstrumentCommand: Unsigned SlashIgnore InstCmd2; /* (purely non-MIDI instrument command: ignore) */
InstrumentCommand: '-' Unsigned {if(last_int_value<128) printf("\\set Staff.midiInstrument = \"%s\"\n",lilypond_inst_names[last_int_value]);} SlashIgnore InstCmd2;
InstrumentCommand: NoteLetter Integer; /* actually a percussion-stave command */
InstrumentCommand: M MidiDump; /* ignore */
InstCmd2: | ',' Integer /* chorus */ InstCmd3;
InstCmd3: | ',' Integer /* reverb */ InstCmd4;
InstCmd4: | ',' Integer /* pan */ InstCmd5;
InstCmd5: | ',' Integer /* balance */ InstCmd6;
InstCmd6: | ',' Integer /* map */ {if(last_int_value<128) printf("\\set Staff.midiInstrument = \"%s\" %% TODO delete the previous setting (has been re-mapped)\n",lilypond_inst_names[last_int_value]);} InstCmd7;
InstCmd7: | ',' MidiDump;
InstDefChars /* for FM instruments */: HexDigit HexDigit HexDigit HexDigit HexDigit HexDigit HexDigit HexDigit HexDigit HexDigit HexDigit HexDigit HexDigit HexDigit HexDigit HexDigit HexDigit HexDigit HexDigit HexDigit HexDigit HexDigit;
MidiDump: /* empty */ | MidiDump HexDigit HexDigit | MidiDump X | MidiDump Y;
HexDigit: '0'|'1'|'2'|'3'|'4'|'5'|'6'|'7'|'8'|'9'|A|B|C|D|E|F;
MaybeSlash: | '/' MaybeTuplet;
MaybeInteger: Integer | ;
CommandCanEndInt: '$' F MaybeInteger {flush_fullbar_rests();puts(" %{ TODO notehead type %} ");};
CommandNoIntOrSetupCommand: X /* TODO if capital, box around the text */
  Integer /* font no. */ TextCommand;
TextCommand: ',' /* (TODO actually any non-numeric character, and it knows it's this version because there's already a font loaded, but comma by convention) */
  Integer {markupPos=(last_int_value<3?'^':'_');}
  CommaIgnore /* height[,hoffset] */
  {textBufPtr=0;} LineIgnoreAddbuf '\n';
TextCommand: NotCommaDigitIgnore LineIgnore '\n' /* font */;

CommandCanEndInt: T {if(clef==10) last_int_value=-2; else last_int_value=10; } MaybeInteger MaybeT {
  clef = last_int_value; flush_fullbar_rests();
  switch(clef) {
    case 10: puts("\\clef treble"); break;
    case 17: puts("\\clef \"G^8\""); break;
    case 4: puts("\\clef alto"); break;
    case 2: puts("\\clef tenor"); break;
    case -2: puts("\\clef bass"); break;
    case 5: puts("\\clef \"F^8\""); break;
    case -99: puts("\\clef percussion"); break;
    default: printf("%%{ TODO clef %d %%} ",clef);
  } // TODO if clef is set at the very end of a part, move it to the next part only
};
MaybeT: | T; /* (if present, omit key signature. ignored for now) */

CommandEndIntOrSetupCommand: '$' C Integer {tempoBPM=last_int_value; last_int_value=4; wasDot=0;} CommaIgnore MaybeDot {flush_fullbar_rests();printf("\\tempo %d%s = %d ",last_int_value,wasDot?".":"",tempoBPM);} PlusIgnore; // TODO if ends with a dot, this is a Command not a CommandCanEndInt

CommandCanEndInt: '$' P Integer MaybeDotT MaybePlusT {
  const char* transposType=NULL;
  if(last_int_value<0 && last_int_value>-12) {
    transposType = negative_transpositions[-last_int_value];
  } else if(last_int_value<12) {
    transposType = positive_transpositions[last_int_value];
  } flush_fullbar_rests();
  if(transposType) {
    if(!transposition_to_be_played) printf(" \\transposition %s",transposType);
    if(transposition_to_be_played==2) {
      /* hack for nested transposition - omit closing */
    } else while(transposition_level){printf("} "); transposition_level--;}
    printf(" \\transpose %s c' { ",transposType); transposition_level++;
  } else printf(" %%{ TODO transposition %d semitones %%} ",last_int_value);
  transposition_to_be_played=0;};
MaybeDotT:  | '.' {transposition_to_be_played=1;};
MaybePlusT: | '+' {transposition_to_be_played=2;};

CommandNoIntOrSetupCommand: '$' '*' {flush_fullbar_rests();puts(" %{ TODO toggle cue mode %} ");};
CommandNoIntAtEnd: '$' '/' BarlineType;
BarlineType: '0' {puts("%{ TODO invisible barlines %}");} | '/' {puts("%{ TODO normal barlines %}");} | '-' {puts("%{ TODO dotted barlines %}");};
CommandCanEndInt: Q {last_int_value=1;} MaybeInteger {printf(" %%{ TODO bracket the last %d staves %%} ",last_int_value);};
CommandNoIntAtEnd: '^' {bow="\\upbow ";} MaybeCaret {mystrcat(volBuf,bow);};
CommandNoIntAtEnd: '$' R { rests_are_skips = !rests_are_skips; };
CommandNoIntOrSetupCommand: '$' '#' /* toggle rests-group-to-multibar: ignore as we have Score.skipBars set anyway in Lilypond */;
BarSetupCommand: '$' '|' {flush_fullbar_rests();if(!suppressNextBarline)puts("\\bar \"||\"");} ;
MaybeDoubleBarAtEnd: | '$' '|' {flush_fullbar_rests();if(!suppressNextBarline)puts("\\bar \"|.\"");} ;
CommandEndIntOrSetupCommand: U Integer { /* bar numbering parameters (TODO capital U means box around them; height param 0 turns numbering off) */
  if(last_int_value>0) {
    flush_fullbar_rests();
    printf("\\override Score.BarNumber #'break-visibility = #end-of-line-invisible\n\\set Score.barNumberVisibility = #(every-nth-bar-number-visible %d)\n",last_int_value);
    overridden_lilypond_bar_numbering = 1;
  } else if(overridden_lilypond_bar_numbering) {
    flush_fullbar_rests();
    puts("% TODO restore Lilypond's default bar numbering (before the clef)");
    overridden_lilypond_bar_numbering = 0;
  }
} CommaIgnore;
MaybeSharp: | '#' MaybeTuplet;
MaybeDot: | '.' {wasDot=1;};
BarSetupCommand: PartSelect;
CommandCanEndInt: OpenPhrase;
PartSelect: P Integer {partOK=(last_int_value!=1);} CommaIgnore {
  if (partOK) { close_part(); printf("part%c={ \\setup ",nextPartLetter++);
    int i; for(i=0;i<7;i++) keysigAccidentals[i]=barAccidentals[i]="";
    switch(clef) {
    case 10: break; // treble default
    case 17: puts("\\clef \"G^8\""); break;
    case 4: puts("\\clef alto"); break;
    case 2: puts("\\clef tenor"); break;
    case -2: puts("\\clef bass"); break;
    case 5: puts("\\clef \"F^8\""); break;
    case -99: puts("\\clef percussion"); break;
    default: printf("%%{ TODO clef %d %%} ",clef);
  }
 }
  lilyCurLen=0;
  /* TODO if some things are set BEFORE the part command e.g. instrument, clef, these should be moved to after it */
};
CommaIgnore: | CommaIgnore ',' Integer; /* note: does not specify how many params to expect, unlike real MWR which stops reading (so another comma could be for divisi, but I hope nobody wrote an MWR file that's THAT unclear) */
PlusIgnore: | '+' Integer;
SlashIgnore: | SlashIgnore '/' Integer;
CommandEndIntOrSetupCommand: L UnsignedNonZero {curLen=last_int_value;};
Octave: OctaveUp | OctaveDown | OctaveSelect;
CommandNoIntOrSetupCommand: OctaveUp | OctaveDown;
CommandEndIntOrSetupCommand: OctaveSelect;
OctaveSelect: O Integer {curOctave=last_int_value;};
OctaveDown: '<' {curOctave--;};
OctaveUp:   '>' {curOctave++;};
/* (not doing barline ignore at lex level because some commands eg. text need CRs) */
SpaceTab: ' ' | '\t';
Barline: SpaceTab Barline2 {
  if(!num_fullbar_rests) puts("|");
  memcpy(barAccidentals,keysigAccidentals,sizeof(char*)*7);
} MaybeInteger; /* (if integer, it's 8va params for next bar, ignored (TODO?)) */
Barline2: /* empty */ | Barline2 SpaceTab | Barline2 Ignore SpaceTab;
MaybeClosePhrase: | ClosePhrase; // needs to be before any tuplet }, not after
CommandNoIntAtEnd: TimeTaker /* (well, CAN be int at end if it's decorated with a fermata, but we prefer shift to reduce there) */ MaybeClosePhrase {
  if(textBufPtr) {
    int i; flush_fullbar_rests();
    printf("%c\\markup{",markupPos);
    for(i=0; i<textBufPtr; i++) putchar(textBuf[i]); // TODO escape }s ?
    textBufPtr=0;
    printf("} ");
  }
  if(tuplet_stop_after) {
    int i,len; len=curLen;
    for(i=0; i<=numDots; i++) {
      tuplet_stop_after -= 128/len;
      len*=2;
    }
    if(tuplet_stop_after<=0) {
      printf(" } ");
      tuplet_stop_after = 0;
    }
  }
};
TimeTaker: {flush_fullbar_rests();} Chord {
  if(curLen!=lilyCurLen || numDots!=lilyCurDots) { printf("%d",curLen); lilyCurLen=curLen; lilyCurDots=0; }
  if(numDots!=lilyCurDots) { int i; for(i=0; i<numDots; i++) putchar('.'); lilyCurDots=numDots; }
  putchar(' ');
  if(staccato) printf("-. ");
  if(need_to_open_phrase==2) printf("( ~ ");
  else if(need_to_open_phrase) { if (in_phrase>1) printf("~ "); else printf("( "); } // %{ TODO check if it should be a tie (~) instead %}
  if(*volBuf) { printf("%s ",volBuf); *volBuf=0; }
  if(hasTenuto){printf("%s",hasTenuto);hasTenuto=NULL;};
  need_to_open_phrase = 0;
} NoteExtraSuffices;
TimeTaker: Rest;
/* if-btyacc */ Chord: Note | {putchar('<');inChord=1;} Note ChordWithNext RestOfChord {putchar('>');inChord=0;};
//if-bison: Chord: Note RestOfChord2;
RestOfChord: OctaveChanges Note RestOfChord2;
RestOfChord2: | ChordWithNext RestOfChord;
/* if-btyacc */ ChordWithNext: '&' {putchar(' ');};
//if-bison: ChordWithNext: '&' {printf(" %%{ TODO chord-with-next %%} ");};
OctaveChanges: | OctaveChanges Octave;
Note: NoteLetter {last_accidental=NULL; numDots=0;} NoteSuffices {
  putchar(lastNoteLetter);
  if (last_accidental) barAccidentals[lastNoteLetter-'a'] = last_accidental;
  printf("%s",barAccidentals[lastNoteLetter-'a']);
  {
    int i;
    for (i=1; i<curOctave; i++) putchar('\'');
    for (i=1; i>curOctave; i--) putchar(',');
  }
};
Rest: R {numDots=0;} RestSuffices {
  if(rests_are_skips) {
    flush_fullbar_rests();
    putchar('s');
  } else if(fills_bar()) {
    if(!num_fullbar_rests++) sprintf(fullbar_rest_buf,"R%d%s",curLen,numDots?".":""); // always re-specify length on full-bar rest, in case automatically or manually changed to a multirest
    lilyCurLen=lilyCurDots=0; // always re-specify length on next note too, in case automatically or manually changed to a multirest
  } else {
    flush_fullbar_rests();
    putchar('r');
  }
  if(!num_fullbar_rests) {
  if(curLen!=lilyCurLen || numDots!=lilyCurDots) { printf("%d",curLen); lilyCurLen=curLen; lilyCurDots=0; }
  if(numDots!=lilyCurDots) { int i; for(i=0; i<numDots; i++) putchar('.'); lilyCurDots=numDots; }
  putchar(' '); }
};
NoteSuffices: /* empty */ | NoteSuffices NoteSuffix;
NoteExtraSuffices: /* empty */ | NoteExtraSuffices NoteExtraSuffix;
RestSuffices: /* empty */ | RestSuffices RestSuffix;
NoteSuffix: Flat {last_accidental="es";} IgnoreMinuses;
NoteSuffix: Sharp {last_accidental="is";} IgnoreMinuses;
NoteSuffix: Natural {last_accidental="";} IgnoreMinuses;
NoteSuffix: '?'; /* ignore (draw head wrong side of stem) */
IgnoreMinuses: | IgnoreMinuses '-'; /* typographic adjustments to accidentals */
NoteExtraSuffix: '=' Ornament; /* TODO finish: */
Ornament: MaybeLower '=' {printf("\\trill ");} | MaybeLower '+' {printf("\\mordent ");} | MaybeLower '&' {printf("\\turn ");} | '!' /* flutter */ ; /* might need btyacc because see OrnamentInsideChord */
MaybeLower: | '?'; /* TODO: e.g. turn->reverseturn */
Ornament: B {printf("\\staccatissimo ");/* (shorthand renamed in 2.18 from -| to -! so we'd better write it long to save any confusion if parts of our output are being used without reference to the \version) */} | '.' /* glissandi */ | '_' /* perdendosi */ | Integer {printf("\\fermata ");};
NoteSuffix: '=' OrnamentInsideChord; /* this probably needs btyacc */
OrnamentInsideChord: '-' /* harmonic series (need & followed by highest note) */ ;
Ornament: C | G | A Integer; /* grace note stuff */
NoteLetter: 'a' {lastNoteLetter='a';staccato=0;};
NoteLetter: 'b' {lastNoteLetter='b';staccato=0;};
NoteLetter: 'c' {lastNoteLetter='c';staccato=0;};
NoteLetter: 'd' {lastNoteLetter='d';staccato=0;};
NoteLetter: 'e' {lastNoteLetter='e';staccato=0;};
NoteLetter: 'f' {lastNoteLetter='f';staccato=0;};
NoteLetter: 'g' {lastNoteLetter='g';staccato=0;};
NoteLetter: 'A' {lastNoteLetter='a';staccato=1;};
NoteLetter: 'B' {lastNoteLetter='b';staccato=1;};
NoteLetter: 'C' {lastNoteLetter='c';staccato=1;};
NoteLetter: 'D' {lastNoteLetter='d';staccato=1;};
NoteLetter: 'E' {lastNoteLetter='e';staccato=1;};
NoteLetter: 'F' {lastNoteLetter='f';staccato=1;};
NoteLetter: 'G' {lastNoteLetter='g';staccato=1;};
NoteSuffix: RestSuffix;
NoteSuffix: Tenuto; // if in chord
NoteExtraSuffix: Tenuto{ printf("%s",hasTenuto); if(staccato) printf("-. "); };
NoteSuffix: TieToLast {
  if(inChord) printf(" %%{ TODO go back and insert a ~ before this chord %%} ");
  else printf(" ~ %%{ TODO delete any barline before that ~ %%} "); // (before the note is output)
};
NoteExtraSuffix: TieToLast {printf(" %%{ TODO tie last note to prev one %%} ");}; // if specified after ornaments etc
RestSuffix: Dot {numDots++;};
RestSuffix: '=' Unsigned {printf("\\fermata ");};
Volume: V MaybeFont CommaIgnore VolumeRest {if(!*volBuf || volBuf[strlen(volBuf)-1]==' ') { if(needPling) { printf("%%{ TODO: \\! or the dynamic after %d bar%s %%} ",needPling,(needPling==1)?"":"s"); needPling=0; } } else if(needPling) { printf("%%{ TODO: \\! after %d bar%s, then the dynamic %%} ",needPling,(needPling==1)?"":"s"); needPling=0; }};
VolumeRest: Cresc MaybeVolstringAndOrPlayParam | Volstring TupletOrPlayParam;
MaybeVolstringAndOrPlayParam: /* nothing */ | PlayParam | Volstring TupletOrPlayParam;
TupletOrPlayParam: /* nothing */ | Tuplet | PlayParam;
TupletOrPlayParam: Dot MaybeTuplet; // TODO ANY character out of context can be ignored by MWR, e.g. you can use '.' to separate 'vff' from note 'f'
MaybeFont: | ':' Integer;
Cresc: '<' {mystrcat(volBuf,"\\< ");} MaybeNumBars
            | '>' {mystrcat(volBuf,"\\> ");} MaybeNumBars
	    | C {mystrcat(volBuf,"\\< ");} MaybeNumBars
	    | D {mystrcat(volBuf,"\\> ");} MaybeNumBars;
MaybeNumBars: {needPling=1;} | Integer {needPling=last_int_value;};
PlayParam: ',' Integer;
Volstring: M P {mystrcat(volBuf,"\\mp");};
Volstring: M F {mystrcat(volBuf,"\\mf");};
Volstring: P {mystrcat(volBuf,"\\"); mystrcat(volBuf,"p");} VolstringMorePs;
Volstring: F {mystrcat(volBuf,"\\"); mystrcat(volBuf,"f");} VolstringMoreFs;
VolstringMorePs: | P {mystrcat(volBuf,"p");} VolstringMorePs;
VolstringMoreFs: | F {mystrcat(volBuf,"f");} VolstringMoreFs;
CommandCanEndInt: J UnsignedNonZero {timeTop=last_int_value;} ',' UnsignedNonZero {timeBottom=last_int_value; flush_fullbar_rests(); printf("\\time %d/%d ",timeTop,timeBottom);};
CommandNoIntAtEnd: K '0' /* single char not count as int at end */ MaybeAccidental {
  flush_fullbar_rests();
  puts("\\key c \\major %{ TODO check it's in all the parts %} ");
  { int i; for(i=0;i<7;i++) keysigAccidentals[i]=barAccidentals[i]=""; }
};
MaybeAccidental: | KeyAccidental;
CommandNoIntAtEnd: K UnsignedNonZero KeyAccidental {
  int curAcc,curKey,incAcc;
  char *curKeyExtra="";
  int i; for(i=0;i<7;i++) keysigAccidentals[i]=barAccidentals[i]="";
  if(!strcmp(last_accidental,"is")) {
    curAcc=5; // F
    incAcc=4;
    curKey=6; // G
  } else {
    curAcc=1; // B
    incAcc=3;
    curKey=5; // F
  }
  for(;last_int_value;last_int_value--) {
    keysigAccidentals[curAcc]=last_accidental;
    curAcc=(curAcc+incAcc)%7;
    if(last_int_value>1) {
      curKey=(curKey+incAcc)%7;
      if(incAcc==3) curKeyExtra="es";
    }
  }
  memcpy(barAccidentals,keysigAccidentals,sizeof(char*)*7);
  flush_fullbar_rests();
  printf("\\key %c%s \\major %%{ TODO check it's in all the parts %%} ",curKey+'a',curKeyExtra);
};
KeyAccidental: Sharp {last_accidental="is";};
KeyAccidental: Flat {last_accidental="es";};
CommandNoIntAtEnd: ':'; /* guaranteed unused separator, normally used before a tuplet number but also e.g. v<:f to mean hairpin + note F rather than hairpin to forte */
CommandNoIntAtEnd: '.'; /* sometimes used as a separator */
OpenPhrase: '(' {need_to_open_phrase++; in_phrase++;} MaybeIntList;
MaybeIntList: | Integer CommaIgnore;
CommandNoIntAtEnd: ClosePhrase;
ClosePhrase: ')' {in_phrase--; if (!in_phrase) printf(") ");} MaybeCaret; // ^ = force phrasemark
MaybeCaret: | '^' {bow="\\downbow ";};
A: 'A' | 'a'; B: 'B' | 'b'; C: 'C' | 'c';
D: 'D' | 'd'; E: 'E' | 'e'; F: 'F' | 'f';
G: 'G' | 'g'; H: 'H' | 'h'; I: 'I' | 'i';
J: 'J' | 'j'; K: 'K' | 'k'; L: 'L' | 'l';
M: 'M' | 'm'; N: 'N' | 'n'; O: 'O' | 'o';
P: 'P' | 'p'; Q: 'Q' | 'q'; R: 'R' | 'r';
S: 'S' | 's'; T: 'T' | 't'; U: 'U' | 'u';
V: 'V' | 'v'; W: 'W' | 'w'; X: 'X' | 'x';
Y: 'Y' | 'y'; Z: 'Z' | 'z';
Flat: '-' | '!';
Sharp: '#' | '+';
Natural: 'n' | 'N';
Dot: '.';
Tenuto: '_' { if(staccato) { staccato=0; hasTenuto="-> "; } else hasTenuto="-- "; } TenutoExtra;
TenutoExtra: | '.' { staccato=1; } | '_' { hasTenuto="-> -- "; };
TieToLast: '\'';
Ignore: '\n';
Comment: ';' { printf("%% "); } LineIgnorePrint '\n' { putchar('\n'); };
LineIgnore: /* empty */ | LineIgnore CharIgnore;
LineIgnoreAddbuf: | LineIgnoreAddbuf CharAddbuf;
LineIgnorePrint: | LineIgnorePrint CharPrint;
LyIgnorePrint: | LyIgnorePrint LyCharPrint; /* excludes { */
LyIgnorePrintAll: | LyIgnorePrintAll CharPrint; /* includes { */
LyCharPrint: ' '{putchar(' ');}|'!'{putchar('!');}|'"'{putchar('"');}|'#'{putchar('#');}|'$'{putchar('$');}|'%'{putchar('%');}|'&'{putchar('&');}|'\''{putchar('\'');}|'('{putchar('(');}|')'{putchar(')');}|'*'{putchar('*');}|'+'{putchar('+');}|','{putchar(',');}|'-'{putchar('-');}|'.'{putchar('.');}|'/'{putchar('/');}|'0'{putchar('0');}|'1'{putchar('1');}|'2'{putchar('2');}|'3'{putchar('3');}|'4'{putchar('4');}|'5'{putchar('5');}|'6'{putchar('6');}|'7'{putchar('7');}|'8'{putchar('8');}|'9'{putchar('9');}|':'{putchar(':');}|';'{putchar(';');}|'<'{putchar('<');}|'='{putchar('=');}|'>'{putchar('>');}|'?'{putchar('?');}|'@'{putchar('@');}|'A'{putchar('A');}|'B'{putchar('B');}|'C'{putchar('C');}|'D'{putchar('D');}|'E'{putchar('E');}|'F'{putchar('F');}|'G'{putchar('G');}|'H'{putchar('H');}|'I'{putchar('I');}|'J'{putchar('J');}|'K'{putchar('K');}|'L'{putchar('L');}|'M'{putchar('M');}|'N'{putchar('N');}|'O'{putchar('O');}|'P'{putchar('P');}|'Q'{putchar('Q');}|'R'{putchar('R');}|'S'{putchar('S');}|'T'{putchar('T');}|'U'{putchar('U');}|'V'{putchar('V');}|'W'{putchar('W');}|'X'{putchar('X');}|'Y'{putchar('Y');}|'Z'{putchar('Z');}|'['{putchar('[');}|']'{putchar(']');}|'^'{putchar('^');}|'_'{putchar('_');}|'`'{putchar('`');}|'a'{putchar('a');}|'b'{putchar('b');}|'c'{putchar('c');}|'d'{putchar('d');}|'e'{putchar('e');}|'f'{putchar('f');}|'g'{putchar('g');}|'h'{putchar('h');}|'i'{putchar('i');}|'j'{putchar('j');}|'k'{putchar('k');}|'l'{putchar('l');}|'m'{putchar('m');}|'n'{putchar('n');}|'o'{putchar('o');}|'p'{putchar('p');}|'q'{putchar('q');}|'r'{putchar('r');}|'s'{putchar('s');}|'t'{putchar('t');}|'u'{putchar('u');}|'v'{putchar('v');}|'w'{putchar('w');}|'x'{putchar('x');}|'y'{putchar('y');}|'z'{putchar('z');}|'}'{putchar('}');}|'|'{putchar('|');}|'\\'{putchar('\\');}|'~'{putchar('~');};
CharPrint: LyCharPrint | '{'{putchar('{');};
CharAddbuf: ' '{bufChar(' ');}|'!'{bufChar('!');}|'"'{bufChar('"');}|'#'{bufChar('#');}|'$'{bufChar('$');}|'%'{bufChar('%');}|'&'{bufChar('&');}|'\''{bufChar('\'');}|'('{bufChar('(');}|')'{bufChar(')');}|'*'{bufChar('*');}|'+'{bufChar('+');}|','{bufChar(',');}|'-'{bufChar('-');}|'.'{bufChar('.');}|'/'{bufChar('/');}|'0'{bufChar('0');}|'1'{bufChar('1');}|'2'{bufChar('2');}|'3'{bufChar('3');}|'4'{bufChar('4');}|'5'{bufChar('5');}|'6'{bufChar('6');}|'7'{bufChar('7');}|'8'{bufChar('8');}|'9'{bufChar('9');}|':'{bufChar(':');}|';'{bufChar(';');}|'<'{bufChar('<');}|'='{bufChar('=');}|'>'{bufChar('>');}|'?'{bufChar('?');}|'@'{bufChar('@');}|'A'{bufChar('A');}|'B'{bufChar('B');}|'C'{bufChar('C');}|'D'{bufChar('D');}|'E'{bufChar('E');}|'F'{bufChar('F');}|'G'{bufChar('G');}|'H'{bufChar('H');}|'I'{bufChar('I');}|'J'{bufChar('J');}|'K'{bufChar('K');}|'L'{bufChar('L');}|'M'{bufChar('M');}|'N'{bufChar('N');}|'O'{bufChar('O');}|'P'{bufChar('P');}|'Q'{bufChar('Q');}|'R'{bufChar('R');}|'S'{bufChar('S');}|'T'{bufChar('T');}|'U'{bufChar('U');}|'V'{bufChar('V');}|'W'{bufChar('W');}|'X'{bufChar('X');}|'Y'{bufChar('Y');}|'Z'{bufChar('Z');}|'['{bufChar('[');}|'\\'{bufChar('\\');}|']'{bufChar(']');}|'^'{bufChar('^');}|'_'{bufChar('_');}|'`'{bufChar('`');}|'a'{bufChar('a');}|'b'{bufChar('b');}|'c'{bufChar('c');}|'d'{bufChar('d');}|'e'{bufChar('e');}|'f'{bufChar('f');}|'g'{bufChar('g');}|'h'{bufChar('h');}|'i'{bufChar('i');}|'j'{bufChar('j');}|'k'{bufChar('k');}|'l'{bufChar('l');}|'m'{bufChar('m');}|'n'{bufChar('n');}|'o'{bufChar('o');}|'p'{bufChar('p');}|'q'{bufChar('q');}|'r'{bufChar('r');}|'s'{bufChar('s');}|'t'{bufChar('t');}|'u'{bufChar('u');}|'v'{bufChar('v');}|'w'{bufChar('w');}|'x'{bufChar('x');}|'y'{bufChar('y');}|'z'{bufChar('z');}|'{'{bufChar('{');}|'|'{bufChar('|');}|'}'{bufChar('}');}|'~'{bufChar('~');};
NotCommaDigitIgnore: ' '|'!'|'"'|'#'|'$'|'%'|'&'|'\''|'('|')'|'*'|'+'|'-'|'.'|'/'|':'|';'|'<'|'='|'>'|'?'|'@'|'A'|'B'|'C'|'D'|'E'|'F'|'G'|'H'|'I'|'J'|'K'|'L'|'M'|'N'|'O'|'P'|'Q'|'R'|'S'|'T'|'U'|'V'|'W'|'X'|'Y'|'Z'|'['|'\\'|']'|'^'|'_'|'`'|'a'|'b'|'c'|'d'|'e'|'f'|'g'|'h'|'i'|'j'|'k'|'l'|'m'|'n'|'o'|'p'|'q'|'r'|'s'|'t'|'u'|'v'|'w'|'x'|'y'|'z'|'{'|'|'|'}'|'~';
CharIgnore: NotCommaDigitIgnore | ','|'0'|'1'|'2'|'3'|'4'|'5'|'6'|'7'|'8'|'9';

Integer: Unsigned | '-' Unsigned {last_int_value=-last_int_value;};
Unsigned: {last_int_value=0;} Digit RestOfUnsigned;
UnsignedNonZero: {last_int_value=0;} DigitNonZero RestOfUnsigned;
RestOfUnsigned: /* epsilon */ | RestOfUnsigned Digit;
Digit: '0' {last_int_value*=10;} | DigitNonZero;
DigitNonZero: '1' {last_int_value=last_int_value*10+1;};
DigitNonZero: '2' {last_int_value=last_int_value*10+2;};
DigitNonZero: '3' {last_int_value=last_int_value*10+3;};
DigitNonZero: '4' {last_int_value=last_int_value*10+4;};
DigitNonZero: '5' {last_int_value=last_int_value*10+5;};
DigitNonZero: '6' {last_int_value=last_int_value*10+6;};
DigitNonZero: '7' {last_int_value=last_int_value*10+7;};
DigitNonZero: '8' {last_int_value=last_int_value*10+8;};
DigitNonZero: '9' {last_int_value=last_int_value*10+9;};

MaybeTuplet: | Tuplet;
Tuplet: UnsignedNonZero {fitIn=last_int_value;} TupletBottomVal {
  flush_fullbar_rests(); printf(" \\times %d/%d { ",last_int_value,fitIn);
  tuplet_stop_after = fitIn*128/curLen;
} MaybeEquals; /* TODO if '=' then don't print a tuplet bracket */
MaybeEquals: | '=';
TupletBottomVal: /* empty */ {
  { int i=2;
    while(i<fitIn) i*=2;
    if(i==fitIn) last_int_value=fitIn*3/2;
    else last_int_value=i/2;
  }
};
TupletBottomVal: '&' Integer;
%%

int theLineNumber=1,theColNumber=0,theCharacter;
// colNumber will actually start at 1 - column 0 will be the new line
// on the line before

int yylex () {
  int c='\r';
  while(c=='\r') { c=getchar(); theCharacter=c; }
  if(c=='\n') { theLineNumber++; theColNumber=0; }
  else theColNumber++;
  if(c==EOF) return 0;
  else if(c>=127) return ' '; // hack
  else return c;
}

int yyerror (const char* s) {
  int c;
  fprintf(stderr,"Line %d col %d: %s (got `'%c'')\nRest of line: ",theLineNumber,theColNumber,s,theCharacter);
  do fputc(c=getchar(),stderr); while (c!='\n' && !feof(stdin));
  exit(1);
}

int main() {
  puts("\\version \"2.12.2\"\n#(set-global-staff-size 20) % (TODO adjust as needed: 25.2 is larger, 17.82 or 15.87 is smaller)\nsetup={\\override Staff.TimeSignature #'style = #'numbered\n\\override Score.Hairpin #'after-line-breaking = ##t\n#(set-accidental-style 'modern-cautionary) % not MWR behaviour but a nice addition\n\\set Score.skipBars = ##t % MWR needs $# to turn this on but we might as well have it by default\n}\npartA={ \\setup "); nextPartLetter++; // (did leave setup block open, so bar-numbering etc goes into it if part is not yet selected, but that's not good: P1 is optional, so need to begin part 1 anyway.  will have to sort out bar numbering anomalies by hand.)
  // (layout-set-staff-size for different size score/parts doesn't always work properly)
  yyparse();
  close_part();
  if(nextPartLetter=='B') { // 1 part
    puts("%{ TODO add \\header{} block %}\n\\score { << \\new Staff << \\context Voice = TheMusic { \\partA } >> >> \\layout{} \\midi{} }");
  } else {
    puts("\\bookpart{ %{ TODO add \\header{} block for the score %}");
    puts("\\score { <<");
    char i='A';
    if(shortScore)
      for(; i+1<nextPartLetter; i+=2)
        printf("\\new Staff << \\context Voice = Part%c%c { << \\part%c \\\\ \\part%c >> } >>\n",i,i+1,i,i+1);
    for(; i<nextPartLetter; i++)
      printf("\\new Staff << \\context Voice = Part%c { \\part%c } >>\n",i,i);
    if(hadRepeats) {
      puts(">> \\layout{} } \\score { \\unfoldRepeats { <<");
      for(i='A'; i<nextPartLetter; i++) {
        printf("\\new Staff << \\context Voice = Part%c { \\part%c } >>\n",i,i);
      }
      puts(">> } \\midi{} }");
    } else puts(">> \\layout{} \\midi{} }");
    if(nextPartLetter=='B' || shortScore) puts("}");
    else {
      puts("} %{ end of score (delete from this point if you don't also want a set of parts)\n TODO \\headers for parts can contain instrument=..., but\n if they do then you might want to put the parts in separate .ly files instead of using bookpart,\n because Lilypond 2.12 puts the instrument header twice on the 1st page of a bookpart if it's not the first bookpart.\n For short pieces it's better to just set staff.instrumentName %}\n");
      for(i='A'; i<nextPartLetter; i++) {
        printf("\\bookpart{ %%{ TODO add \\header{} for part %c %%}\n",i);
        puts("\\score { <<");
        printf("\\new Staff << \\context Voice = Part%c { \\part%c } >>\n",i,i);
        puts(">> \\layout{} } }");
      }
    }
  }
  exit(0);
}
