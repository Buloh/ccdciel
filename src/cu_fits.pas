unit cu_fits;

{
Copyright (C) 2005-2015 Patrick Chevalley

http://www.ap-i.net
pch@ap-i.net

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>. 

}

{$mode delphi}{$H+}

//{$define debug_raw}

interface

uses SysUtils, Classes, LazFileUtils, u_utils, u_global, BGRABitmap, BGRABitmapTypes, ExpandedBitmap,
  GraphType,  FPReadJPEG, LazSysUtils, u_libraw, dateutils,
  LazUTF8, Graphics,Math, FPImage, Controls, LCLType, Dialogs, u_translation, IntfGraphics;

type

 TFitsInfo = record
            valid, solved, floatingpoint: boolean;
            bitpix,naxis,naxis1,naxis2,naxis3 : integer;
            Frx,Fry,Frwidth,Frheight,BinX,BinY: integer;
            bzero,bscale,dmax,dmin,blank : double;
            bayerpattern: string;
            bayeroffsetx, bayeroffsety: integer;
            rmult,gmult,bmult: double;
            equinox,ra,dec,crval1,crval2: double;
            pixsz1,pixsz2,pixratio,focallen,scale: double;
            exptime,airmass: double;
            objects,ctype1,ctype2 : string;
            end;

 THeaderBlock = array[1..36,1..80] of char;

 TStar = record
         x,y: double;
         hfd, fwhm: double;
         vmax, snr, bg: double;
         end;
 TStarList = array of TStar;

 Timai8 = array of array of array of byte; TPimai8 = ^Timai8;
 Timai16 = array of array of array of smallint; TPimai16 = ^Timai16;
 Timaw16 = array of array of array of word; TPimaw16 = ^Timaw16;
 Timai32 = array of array of array of longint; TPimai32 = ^Timai32;
 Timar32 = array of array of array of single; TPimar32 = ^Timar32;
 Timar64 = array of array of array of double; TPimar64 = ^Timar64;

 THistogram = array[0..high(word)] of integer;

 TMathOperator = (moAdd,moSub,moMean,moMult,moDiv);

 TFitsHeader = class(TObject)
    private
      FRows:   TStringList;
      FKeys:   TStringList;
      FValues: TStringList;
      FComments:TStringList;
      Fvalid : boolean;
    public
      constructor Create;
      destructor  Destroy; override;
      procedure ClearHeader;
      procedure Assign(value: TFitsHeader);
      function ReadHeader(ff:TMemoryStream): integer;
      function NewWCS(ff:TMemoryStream): boolean;
      function GetStream: TMemoryStream;
      function Indexof(key: string): integer;
      function Valueof(key: string; out val: string): boolean; overload;
      function Valueof(key: string; out val: integer): boolean; overload;
      function Valueof(key: string; out val: double): boolean; overload;
      function Valueof(key: string; out val: boolean): boolean; overload;
      function Add(key,val,comment: string; quotedval:boolean=true): integer; overload;
      function Add(key:string; val:integer; comment: string): integer; overload;
      function Add(key:string; val:double; comment: string): integer; overload;
      function Add(key:string; val:boolean; comment: string): integer; overload;
      function Insert(idx: integer; key,val,comment: string; quotedval:boolean=true):integer; overload;
      function Insert(idx: integer; key:string; val:integer; comment: string):integer; overload;
      function Insert(idx: integer; key:string; val:double; comment: string):integer; overload;
      function Insert(idx: integer; key:string; val:boolean; comment: string):integer; overload;
      procedure Delete(idx: integer);
      property Rows:   TStringList read FRows;
      property Keys:   TStringList read FKeys;
      property Values: TStringList read FValues;
      property Comments:TStringList read FComments;
 end;

const    maxl = 20000;

type

  TFits = class(TComponent)
  private
    // Original Fits file
    FStream : TMemoryStream;
    // Fits read buffers
    d8  : array[1..2880] of byte;
    d16 : array[1..1440] of smallint;
    d32 : array[1..720] of Longword;
    d64 : array[1..360] of Int64;
    // Original image data
    imai8 : Timai8;
    imai16 : Timai16;
    imai32 : Timai32;
    imar32 : Timar32;
    imar64 : Timar64;
    // 16bit image scaled min/max unsigned
    Fimage : Timaw16;
    // Fimage scaling factor
    FimageC, FimageMin,FimageMax : double;
    // Histogram of Fimage
    FHistogram: THistogram;
    // Fits header
    FHeader: TFitsHeader;
    // same as Fimage in TLazIntfImage format
    FIntfImg: TLazIntfImage;
    // Fits header values
    FFitsInfo : TFitsInfo;
    //
    n_axis,cur_axis,Fwidth,Fheight,Fhdr_end,colormode : Integer;
    FTitle : string;
    Fmean,Fsigma,Fdmin,Fdmax : double;
    FImgDmin, FImgDmax: Word;
    FImgFullRange,FStreamValid,FImageValid: Boolean;
    Fbpm: TBpm;
    FBPMcount,FBPMnx,FBPMny,FBPMnax: integer;
    gamma_c : array[0..32768] of single; {prepared power values for gamma correction}
    FGamma: single;
    emptybmp:Tbitmap;
    FMarkOverflow: boolean;
    FMaxADU, FOverflow, FUnderflow: double;
    FInvert: boolean;
    FStarList: TStarList;
    FDark: TFits;
    FDarkOn: boolean;
    FDarkProcess, FBPMProcess: boolean;
    FonMsg: TNotifyMsg;
    procedure msg(txt: string; level:integer=3);
    procedure SetStream(value:TMemoryStream);
    function GetStream: TMemoryStream;
    procedure SetVideoStream(value:TMemoryStream);
    Procedure ReadFitsImage;
    Procedure WriteFitsImage;
    Procedure GetImage;
    function GammaCorr(value: Word):byte;
    procedure SetImgFullRange(value: boolean);
    function GetHasBPM: boolean;
    procedure SetGamma(value: single);
    function GetBayerMode: TBayerMode;
  protected
    { Protected declarations }
  public
    { Public declarations }
     constructor Create(AOwner:TComponent); override;
     destructor  Destroy; override;
     function  GetStatistics: string;
     Procedure LoadStream;
     procedure ClearFitsInfo;
     procedure GetFitsInfo;
     function  BayerInterpolationExp(t:TBayerMode; rmult,gmult,bmult:double; pix1,pix2,pix3,pix4,pix5,pix6,pix7,pix8,pix9:integer; row,col:integer):TExpandedPixel; inline;
     function  BayerInterpolation(t:TBayerMode; rmult,gmult,bmult:double; pix1,pix2,pix3,pix4,pix5,pix6,pix7,pix8,pix9:integer; row,col:integer):TBGRAPixel; inline;
     procedure GetExpBitmap(var bgra: TExpandedBitmap; debayer:boolean);
     procedure GetBGRABitmap(var bgra: TBGRABitmap; debayer:boolean);
     procedure SaveToBitmap(fn: string);
     procedure SaveToFile(fn: string; pack: boolean=false);
     procedure LoadFromFile(fn:string);
     procedure SetBPM(value: TBpm; count,nx,ny,nax:integer);
     procedure ApplyBPM;
     procedure ApplyDark;
     procedure FreeDark;
     procedure ClearImage;
     procedure Math(operand: TFits; MathOperator:TMathOperator; new: boolean=false);
     procedure Shift(dx,dy: double);
     procedure ShiftInteger(dx,dy: integer);
     procedure Bitpix8to16;
     function  SameFormat(f:TFits): boolean;
     function  double_star(ri, x,y : integer):boolean;
     function  value_subpixel(x1,y1:double):double;
     procedure FindBrightestPixel(x,y,s,starwindow2: integer; out xc,yc:integer; out vmax: double; accept_double: boolean=true);
     procedure FindStarPos(x,y,s: integer; out xc,yc,ri:integer; out vmax,bg,bg_standard_deviation: double);
     procedure GetHFD2(x,y,s: integer; out xc,yc,bg,bg_standard_deviation,hfd,star_fwhm,valmax,snr,flux: double; strict_saturation: boolean=true);{han.k 2018-3-21}
     procedure GetStarList(rx,ry,s: integer);
     procedure MeasureStarList(s: integer; list: TArrayDouble2);
     procedure ClearStarList;
     property IntfImg: TLazIntfImage read FIntfImg;
     property Title : string read FTitle write FTitle;
     Property HeaderInfo : TFitsInfo read FFitsInfo;
     property Header: TFitsHeader read FHeader write FHeader;
     Property Stream : TMemoryStream read GetStream write SetStream;
     Property VideoStream : TMemoryStream write SetVideoStream;
     property Histogram : THistogram read FHistogram;
     property ImgDmin : Word read FImgDmin write FImgDmin;
     property ImgDmax : Word read FImgDmax write FImgDmax;
     property Gamma: single read FGamma write SetGamma;
     property ImageValid: boolean read FImageValid;
     property image : Timaw16 read Fimage;
     property imageC : double read FimageC;
     property imageMin : double read FimageMin;
     property imageMax : double read FimageMax;
     property imageMean: double read Fmean;
     property imageSigma: double read Fsigma;
     property BayerMode: TBayerMode read GetBayerMode;
     property ImgFullRange: Boolean read FImgFullRange write SetImgFullRange;
     property MaxADU: double read FMaxADU write FMaxADU;
     property Invert: boolean read FInvert write FInvert;
     property MarkOverflow: boolean read FMarkOverflow write FMarkOverflow;
     property Overflow: double read FOverflow write FOverflow;
     property Underflow: double read FUnderflow write FUnderflow;
     property hasBPM: boolean read GetHasBPM;
     property BPMProcess: boolean read FBPMProcess;
     property StarList: TStarList read FStarList;
     property DarkProcess: boolean read FDarkProcess;
     property DarkOn: boolean read FDarkOn write FDarkOn;
     property DarkFrame: TFits read FDark write FDark;
     property onMsg: TNotifyMsg read FonMsg write FonMsg;
  end;

  TGetImage = class(TThread)
  public
    working: boolean;
    num, id: integer;
    fits: TFits;
    hist: THistogram;
    Fdmin,c: double;
    procedure Execute; override;
    constructor Create(CreateSuspended: boolean);
  end;

  TGetBgraThread = class(TThread)
    public
      working: boolean;
      num, id: integer;
      fits: TFits;
      bgra: TBGRABitmap;
      HighOverflow,LowOverflow: TBGRAPixel;
      c,overflow,underflow: double;
      rmult,gmult,bmult,mx: double;
      debayer: boolean;
      t: TBayerMode;
      FImgDmin: word;
      procedure Execute; override;
      constructor Create(CreateSuspended: boolean);
    end;

   TGetExpThread = class(TThread)
    public
      working: boolean;
      num, id: integer;
      fits: TFits;
      bgra: TExpandedBitmap;
      rmult,gmult,bmult,mx: double;
      debayer: boolean;
      t: TBayerMode;
      procedure Execute; override;
      constructor Create(CreateSuspended: boolean);
    end;

    TGetStarList = class(TThread)
    public
      working: boolean;
      num, id: integer;
      fits: TFits;
      StarList: TStarList;
      rx,ry,overlap,s: integer;
      img_temp: Timai8;
      procedure Execute; override;
      constructor Create(CreateSuspended: boolean);
    end;



  procedure PictureToFits(pict:TMemoryStream; ext: string; var ImgStream:TMemoryStream; flip:boolean=true;pix:double=-1;piy:double=-1;binx:integer=-1;biny:integer=-1;bayer:string='';rmult:string='';gmult:string='';bmult:string='';origin:string='';exifkey:TStringList=nil;exifvalue:TStringList=nil);
  procedure RawToFits(raw:TMemoryStream; var ImgStream:TMemoryStream; out rmsg:string; pix:double=-1;piy:double=-1;binx:integer=-1;biny:integer=-1);
  function PackFits(unpackedfilename,packedfilename: string; out rmsg:string):integer;
  function UnpackFits(packedfilename: string; var ImgStream:TMemoryStream; out rmsg:string):integer;

implementation

//////////////////// TFitsHeader /////////////////////////

constructor TFitsHeader.Create;
begin
  inherited Create;
  FRows:=TStringList.Create;
  FComments:=TStringList.Create;
  FValues:=TStringList.Create;
  FKeys:=TStringList.Create;
  Fvalid:=false;
end;

destructor  TFitsHeader.Destroy;
begin
  FRows.Free;
  FComments.Free;
  FValues.Free;
  FKeys.Free;
  inherited Destroy;
end;

procedure TFitsHeader.ClearHeader;
begin
  Fvalid:=false;
  FRows.Clear;
  FKeys.Clear;
  FValues.Clear;
  FComments.Clear;
end;

procedure TFitsHeader.Assign(value: TFitsHeader);
begin
  ClearHeader;
  FRows.Assign(value.FRows);
  FKeys.Assign(value.FKeys);
  FValues.Assign(value.FValues);
  FComments.Assign(value.FComments);
  Fvalid:=value.Fvalid;
 end;

function TFitsHeader.NewWCS(ff:TMemoryStream): boolean;
var header : THeaderBlock;
    i,p1,p2,n,ii : integer;
    eoh : boolean;
    row,keyword,value,comment,buf : string;
    P: PChar;
const excl1:array[0..18] of string=('CTYPE','WCSAXES','EQUINOX','LONPOLE','LATPOLE','CRVAL','CRPIX','CUNIT','CD','CDELT','A_','B_','AP_','BP_','PV','CROTA','END','IMAGEW','IMAGEH');
      excl2:array[0..3] of string=('SIMPLE','BITPIX','EXTEND','NAXIS');
  function IsKeywordIn(k:string; klist:array of string): boolean;
  var j: integer;
  begin
    result:=false;
    for j:=0 to Length(klist)-1 do begin
      if pos(klist[j],k)=1 then begin
        result:=true;
        break;
      end;
    end;
  end;

begin
 result:=false;
 if FKeys.Count>0 then begin
   // delete old wcs
   for i:=FKeys.Count-1 downto 0 do begin
     if IsKeywordIn(FKeys[i],excl1) then begin
        Delete(i);
     end;
   end;
   // load new wcs
   eoh:=false;
   ff.Position:=0;
   header[1,1]:=chr(0);
   repeat
      n:=ff.Read(header,sizeof(THeaderBlock));
      if n<>sizeof(THeaderBlock) then
         Break;
      for i:=1 to 36 do begin
         row:=header[i];
         if trim(row)='' then continue;
         p1:=9;
         p2:=pos('/',row);
         keyword:=trim(copy(row,1,p1-1));
         if p2>0 then begin
            value:=trim(copy(row,p1+1,p2-p1-1));
            comment:=trim(copy(row,p2,99));
         end else begin
            value:=trim(copy(row,p1+1,99));
            comment:='';
         end;
         if (keyword='SIMPLE') then
            if (copy(value,1,1)='T') then begin
              Fvalid:=true;
            end
            else begin
              Fvalid:=false;
              Break;
            end;
         if (keyword='END') then begin
            eoh:=true;
         end;
         P:=PChar(value);
         buf:=AnsiExtractQuotedStr(P,'''');
         if buf<>'' then value:=buf;
         if not IsKeywordIn(keyword,excl2) then begin
           if (keyword<>'')and(keyword<>'COMMENT')and(keyword<>'HISTORY') then
             ii:=FKeys.IndexOf(keyword)
           else
             ii:=-1;
           if ii<0 then begin
             FRows.add(row);
             FKeys.add(keyword);
             FValues.add(value);
             FComments.add(comment);
           end
           else begin
             FRows[ii]:=row;
             FKeys[ii]:=keyword;
             FValues[ii]:=value;
             FComments[ii]:=comment;
           end;
         end;
      end;
      if not Fvalid then begin
        Break;
      end;
   until eoh;
 end;
end;

function TFitsHeader.ReadHeader(ff:TMemoryStream): integer;
var   header : THeaderBlock;
      i,p1,p2,n : integer;
      eoh : boolean;
      row,keyword,value,comment,buf : string;
      P: PChar;
begin
ClearHeader;
eoh:=false;
ff.Position:=0;
header[1,1]:=chr(0);
repeat
   n:=ff.Read(header,sizeof(THeaderBlock));
   if n<>sizeof(THeaderBlock) then
      Break;
   for i:=1 to 36 do begin
      row:=header[i];
      if trim(row)='' then continue;
      p1:=9;
      p2:=pos('/',row);
      keyword:=trim(copy(row,1,p1-1));
      if p2>0 then begin
         value:=trim(copy(row,p1+1,p2-p1-1));
         comment:=trim(copy(row,p2,99));
      end else begin
         value:=trim(copy(row,p1+1,99));
         comment:='';
      end;
      if (keyword='SIMPLE') then
         if (copy(value,1,1)='T') then begin
           Fvalid:=true;
         end
         else begin
           Fvalid:=false;
           Break;
         end;
      if (keyword='END') then begin
         eoh:=true;
      end;
      P:=PChar(value);
      buf:=AnsiExtractQuotedStr(P,'''');
      if buf<>'' then value:=buf;
      FRows.add(row);
      FKeys.add(keyword);
      FValues.add(value);
      FComments.add(comment);
   end;
   if not Fvalid then begin
     Break;
   end;
until eoh;
result:=ff.position;
end;

function TFitsHeader.GetStream: TMemoryStream;
var i,c:integer;
    buf: array[0..79] of char;
begin
  result:=TMemoryStream.Create;
  for i:=0 to FRows.Count-1 do begin
    buf:=FRows[i];
    result.Write(buf,80);
  end;
  if (FRows.Count mod 36)>0 then begin
    buf:=b80;
    c:=36 - (FRows.Count mod 36);
    for i:=1 to c do result.Write(buf,80);
  end;
end;

function TFitsHeader.Indexof(key: string): integer;
begin
  result:=FKeys.IndexOf(key);
end;

function CleanASCII(txt: string):string;
var i: integer;
begin
result:='';
for i:=1 to length(txt) do begin
  if (txt[i]>=#32)and(txt[i]<=#126) then
    result:=result+txt[i]
  else
    result:=result+blank;
end;
end;

function TFitsHeader.Valueof(key: string; out val: string): boolean; overload;
var k: integer;
begin
  val:='';
  k:=FKeys.IndexOf(key);
  result:=(k>=0);
  if result then val:=FValues[k];
end;

function TFitsHeader.Valueof(key: string; out val: integer): boolean; overload;
var k: integer;
begin
  val:=0;
  k:=FKeys.IndexOf(key);
  result:=(k>=0);
  if result then val:=StrToIntDef(trim(FValues[k]),0);
end;

function TFitsHeader.Valueof(key: string; out val: double): boolean; overload;
var k: integer;
begin
  val:=0;
  k:=FKeys.IndexOf(key);
  result:=(k>=0);
  if result then val:=StrToFloatDef(trim(FValues[k]),0);
end;

function TFitsHeader.Valueof(key: string; out val: boolean): boolean; overload;
var k: integer;
begin
  val:=false;
  k:=FKeys.IndexOf(key);
  result:=(k>=0);
  if result then val:=(trim(FValues[k])='T');
end;

function TFitsHeader.Add(key,val,comment: string; quotedval:boolean=true): integer;
begin
 result:=Insert(-1,key,val,comment,quotedval);
end;

function TFitsHeader.Add(key:string; val:integer; comment: string): integer;
begin
 result:=Insert(-1,key,val,comment);
end;

function TFitsHeader.Add(key:string; val:double; comment: string): integer;
begin
 result:=Insert(-1,key,val,comment);
end;

function TFitsHeader.Add(key:string; val:boolean; comment: string): integer;
begin
 result:=Insert(-1,key,val,comment);
end;

function TFitsHeader.Insert(idx: integer; key,val,comment: string; quotedval:boolean=true): integer;
var row: string;
    ii: integer;
begin
 val:=CleanASCII(val);
 comment:=CleanASCII(comment);
 // The END keyword
 if (trim(key)='END') then begin
   row:=copy('END'+b80,1,80);
   val:='';
   comment:='';
 end
 // hierarch
 else if (trim(key)='HIERARCH') then begin
    row:=Format('%0:-8s',[key])+
         Format(' %0:-70s',[val]);
    if comment>'' then
       row:=row+Format(' / %0:-47s',[comment])
    else
       row:=row+b80;
 end
 // Comments with keyword
 else if (trim(key)='COMMENT') then begin
   val:=val+comment;
   comment:='';
   row:=Format('%0:-8s',[key])+
        Format('  %0:-70s',[val]);
 end
 // Comment without keyword
 else if (trim(key)='') then begin
   val:=val+comment;
   comment:='';
   row:=Format('          %0:-70s',[val]);
 end
 // Quoted string
 else if quotedval then begin
    row:=Format('%0:-8s',[key])+
         Format('= %0:-20s',[QuotedStr(val)]);
         if comment>'' then
            row:=row+Format(' / %0:-47s',[comment])
         else
            row:=row+b80;
 end
 // Other unquoted values
 else begin
    row:=Format('%0:-8s',[key])+
         Format('= %0:-20s',[val]);
         if comment>'' then
            row:=row+Format(' / %0:-47s',[comment])
         else
            row:=row+b80;
 end;
 row:=copy(row,1,80);
 // Search for existing key
 if (key<>'')and(key<>'COMMENT')and(key<>'HISTORY')and(key<>'HIERARCH') then
   ii:=FKeys.IndexOf(key)
 else
   ii:=-1;
 if ii>=0 then begin
    // replace existing key
    FRows[ii]:=row;
    FKeys[ii]:=key;
    FValues[ii]:=val;
    FComments[ii]:=comment;
    result:=ii;
 end
 else if idx>=0 then begin
    // insert key at position
    FRows.Insert(idx,row);
    FKeys.Insert(idx,key);
    FValues.Insert(idx,val);
    FComments.Insert(idx,comment);
    result:=idx;
 end else begin
    // add key at end
    result:=FRows.Add(row);
    FKeys.Add(key);
    FValues.Add(val);
    FComments.Add(comment);
 end;
end;

function TFitsHeader.Insert(idx: integer; key:string; val:integer; comment: string):integer;
var txt: string;
begin
  txt:=Format('%20d',[val]);
  result:=Insert(idx,key,txt,comment,false);
end;

function TFitsHeader.Insert(idx: integer; key:string; val:double; comment: string):integer;
var txt: string;
begin
  txt:=Format('%20.10g',[val]);
  result:=Insert(idx,key,txt,comment,false);
end;

function TFitsHeader.Insert(idx: integer; key:string; val:boolean; comment: string):integer;
var txt,v: string;
begin
  if val then v:='T' else v:='F';
  txt:=Format('%0:20s',[v]);
  result:=Insert(idx,key,txt,comment,false);
  if (not Fvalid)and(key='SIMPLE')and(val) then Fvalid:=true;
end;

procedure TFitsHeader.Delete(idx: integer);
begin
  FRows.Delete(idx);
  FKeys.Delete(idx);
  FValues.Delete(idx);
  FComments.Delete(idx);
end;

//////////////////// TGetImage /////////////////////////

constructor TGetImage.Create(CreateSuspended: boolean);
begin
  FreeOnTerminate := False;
  inherited Create(CreateSuspended);
  working := True;
end;

procedure TGetImage.Execute;
var
  i, j, startline, endline, xs,ys: integer;
  x : word;
  h: integer;
  xx: extended;
begin
xs:= fits.Fwidth;
ys:= fits.FHeight;
i := ys div num;
startline := id * i;
if id = (num - 1) then
  endline := ys - 1
else
  endline := (id + 1) * i - 1;
FillByte(hist,sizeof(THistogram),0);
// process the rows range for this thread
case fits.FFitsInfo.bitpix of
   -64 : begin
         for i:=startline to endline do begin
         for j := 0 to xs-1 do begin
             xx:=fits.FFitsInfo.bzero+fits.FFitsInfo.bscale*fits.imar64[0,i,j];
             x:=round(max(0,min(MaxWord,(xx-Fdmin) * c )) );
             fits.Fimage[0,i,j]:=x;
             if fits.n_axis=3 then begin
               h:=x;
               xx:=fits.FFitsInfo.bzero+fits.FFitsInfo.bscale*fits.imar64[1,i,j];
               x:=round(max(0,min(MaxWord,(xx-Fdmin) * c )) );
               fits.Fimage[1,i,j]:=x;
               h:=h+x;
               xx:=fits.FFitsInfo.bzero+fits.FFitsInfo.bscale*fits.imar64[2,i,j];
               x:=round(max(0,min(MaxWord,(xx-Fdmin) * c )) );
               fits.Fimage[2,i,j]:=x;
               x:=(h+x) div 3;
             end;
             inc(hist[x]);
         end;
         end;
         end;
   -32 : begin
         for i:=startline to endline do begin
         for j := 0 to xs-1 do begin
             xx:=fits.FFitsInfo.bzero+fits.FFitsInfo.bscale*fits.imar32[0,i,j];
             x:=round(max(0,min(MaxWord,(xx-Fdmin) * c )) );
             fits.Fimage[0,i,j]:=x;
             if fits.n_axis=3 then begin
               h:=x;
               xx:=fits.FFitsInfo.bzero+fits.FFitsInfo.bscale*fits.imar32[1,i,j];
               x:=round(max(0,min(MaxWord,(xx-Fdmin) * c )) );
               fits.Fimage[1,i,j]:=x;
               h:=h+x;
               xx:=fits.FFitsInfo.bzero+fits.FFitsInfo.bscale*fits.imar32[2,i,j];
               x:=round(max(0,min(MaxWord,(xx-Fdmin) * c )) );
               fits.Fimage[2,i,j]:=x;
               x:=(h+x) div 3;
             end;
             inc(hist[x]);
         end;
         end;
         end;
     8 : begin
         for i:=startline to endline do begin
         for j := 0 to xs-1 do begin
             xx:=fits.FFitsInfo.bzero+fits.FFitsInfo.bscale*fits.imai8[0,i,j];
             x:=round(max(0,min(MaxWord,(xx-Fdmin) * c )) );
             fits.Fimage[0,i,j]:=x;
             if fits.n_axis=3 then begin
               h:=x;
               xx:=fits.FFitsInfo.bzero+fits.FFitsInfo.bscale*fits.imai8[1,i,j];
               x:=round(max(0,min(MaxWord,(xx-Fdmin) * c )) );
               fits.Fimage[1,i,j]:=x;
               h:=h+x;
               xx:=fits.FFitsInfo.bzero+fits.FFitsInfo.bscale*fits.imai8[2,i,j];
               x:=round(max(0,min(MaxWord,(xx-Fdmin) * c )) );
               fits.Fimage[2,i,j]:=x;
               x:=(h+x) div 3;
             end;
             inc(hist[x]);
         end;
         end;
         end;
    16 : begin
         for i:=startline to endline do begin
         for j := 0 to xs-1 do begin
             xx:=fits.FFitsInfo.bzero+fits.FFitsInfo.bscale*fits.imai16[0,i,j];
             x:=round(max(0,min(MaxWord,(xx-Fdmin) * c )) );
             fits.Fimage[0,i,j]:=x;
             if fits.n_axis=3 then begin
               h:=x;
               xx:=fits.FFitsInfo.bzero+fits.FFitsInfo.bscale*fits.imai16[1,i,j];
               x:=round(max(0,min(MaxWord,(xx-Fdmin) * c )) );
               fits.Fimage[1,i,j]:=x;
               h:=h+x;
               xx:=fits.FFitsInfo.bzero+fits.FFitsInfo.bscale*fits.imai16[2,i,j];
               x:=round(max(0,min(MaxWord,(xx-Fdmin) * c )) );
               fits.Fimage[2,i,j]:=x;
               x:=(h+x) div 3;
             end;
             inc(hist[x]);
         end;
         end;
         end;
    32 : begin
         for i:=startline to endline do begin
         for j := 0 to xs-1 do begin
             xx:=fits.FFitsInfo.bzero+fits.FFitsInfo.bscale*fits.imai32[0,i,j];
             x:=round(max(0,min(MaxWord,(xx-Fdmin) * c )) );
             fits.Fimage[0,i,j]:=x;
             if fits.n_axis=3 then begin
               h:=x;
               xx:=fits.FFitsInfo.bzero+fits.FFitsInfo.bscale*fits.imai32[1,i,j];
               x:=round(max(0,min(MaxWord,(xx-Fdmin) * c )) );
               fits.Fimage[1,i,j]:=x;
               h:=h+x;
               xx:=fits.FFitsInfo.bzero+fits.FFitsInfo.bscale*fits.imai32[2,i,j];
               x:=round(max(0,min(MaxWord,(xx-Fdmin) * c )) );
               fits.Fimage[2,i,j]:=x;
               x:=(h+x) div 3;
             end;
             inc(hist[x]);
         end;
         end;
         end;
    end;

working := False;
end;

//////////////////// TGetBgraThread /////////////////////////

constructor TGetBgraThread.Create(CreateSuspended: boolean);
begin
  FreeOnTerminate := True;
  inherited Create(CreateSuspended);
  working := True;
end;

procedure TGetBgraThread.Execute;
var
  i, j, startline, endline, xs,ys: integer;
  ii,i1,i2,i3,j1,j2,j3 : integer;
  x : word;
  xx,xxg,xxb: extended;
  p: PBGRAPixel;
  pix1,pix2,pix3,pix4,pix5,pix6,pix7,pix8,pix9:integer;

begin
xs:= fits.Fwidth;
ys:= fits.FHeight;
i := ys div num;
startline := id * i;
if id = (num - 1) then
  endline := ys - 1
else
  endline := (id + 1) * i - 1;
ii:=0; i1:=0; i2:=0; i3:=0;
// process the rows range for this thread
for i:=startline to endline do begin
   if debayer then begin
     ii:=ys-1-i; // image is flipped in fits, count color order from the bottom
     i1:=max(i-1,0);
     i2:=i;
     i3:= min(i+1,ys-1);
   end;
   p := bgra.Scanline[i];
   for j := 0 to xs-1 do begin
       if fits.HeaderInfo.naxis=3 then begin
         // 3 chanel color image
         xx:=fits.image[0,i,j];
         x:=round(max(0,min(MaxWord,(xx-FImgDmin) * c )) );
         p^.red:=fits.GammaCorr(x);
         xxg:=fits.image[1,i,j];
         x:=round(max(0,min(MaxWord,(xxg-FImgDmin) * c )) );
         p^.green:=fits.GammaCorr(x);
         xxb:=fits.image[2,i,j];
         x:=round(max(0,min(MaxWord,(xxb-FImgDmin) * c )) );
         p^.blue:=fits.GammaCorr(x);
         if fits.MarkOverflow then begin
           if maxvalue([xx,xxg,xxb])>=overflow then
             p^:=HighOverflow
           else if minvalue([xx,xxg,xxb])<=underflow then
             p^:=LowOverflow;
         end;
       end else begin
         if debayer then begin
           j1:=max(j-1,0);
           j2:=j;
           j3:=min(j+1,xs-1);
           pix1:=round((fits.image[0,i1,j1]-FImgDmin) * c );
           pix2:=round((fits.image[0,i1,j2]-FImgDmin) * c );
           pix3:=round((fits.image[0,i1,j3]-FImgDmin) * c );
           pix4:=round((fits.image[0,i2,j1]-FImgDmin) * c );
           pix5:=round((fits.image[0,i2,j2]-FImgDmin) * c );
           pix6:=round((fits.image[0,i2,j3]-FImgDmin) * c );
           pix7:=round((fits.image[0,i3,j1]-FImgDmin) * c );
           pix8:=round((fits.image[0,i3,j2]-FImgDmin) * c );
           pix9:=round((fits.image[0,i3,j3]-FImgDmin) * c );
           p^:=fits.BayerInterpolation(t,rmult,gmult,bmult,pix1,pix2,pix3,pix4,pix5,pix6,pix7,pix8,pix9,ii,j);
         end else begin
           // B/W image
           xx:=fits.image[0,i,j];
           x:=round(max(0,min(MaxWord,(xx-FImgDmin) * c )) );
           p^.red:=fits.GammaCorr(x);
           p^.green:=p^.red;
           p^.blue:=p^.red;
           if fits.MarkOverflow then begin
             if xx>=overflow then
               p^:=HighOverflow
             else if xx<=underflow then
               p^:=LowOverflow;
           end;
         end;
       end;
       p^.alpha:=255;
       inc(p);
   end;
end;
working := False;
end;

//////////////////// TGetExpThread /////////////////////////

constructor TGetExpThread.Create(CreateSuspended: boolean);
begin
  FreeOnTerminate := True;
  inherited Create(CreateSuspended);
  working := True;
end;

procedure TGetExpThread.Execute;
var
  i, j, startline, endline, xs,ys: integer;
  ii,i1,i2,i3,j1,j2,j3 : integer;
  x : word;
  xx,xxg,xxb: extended;
  p: PExpandedPixel;
  pix1,pix2,pix3,pix4,pix5,pix6,pix7,pix8,pix9:integer;

begin
xs:= fits.Fwidth;
ys:= fits.FHeight;
i := ys div num;
startline := id * i;
if id = (num - 1) then
  endline := ys - 1
else
  endline := (id + 1) * i - 1;
ii:=0; i1:=0; i2:=0; i3:=0;
// process the rows range for this thread
for i:=startline to endline do begin
   if debayer then begin
     ii:=ys-1-i; // image is flipped in fits, count color order from the bottom
     i1:=max(i-1,0);
     i2:=i;
     i3:= min(i+1,ys-1);
   end;
   p := bgra.Scanline[i];
   for j := 0 to xs-1 do begin
       if fits.HeaderInfo.naxis=3 then begin
         // 3 chanel color image
         xx:=fits.imageMin+fits.image[0,i,j]/fits.imageC;
         x:=round(max(0,min(MaxWord,xx)) );
         p^.red:=x;
         xxg:=fits.imageMin+fits.image[1,i,j]/fits.imageC;
         x:=round(max(0,min(MaxWord,xxg)) );
         p^.green:=x;
         xxb:=fits.imageMin+fits.image[2,i,j]/fits.imageC;
         x:=round(max(0,min(MaxWord,xxb)) );
         p^.blue:=x;
       end else begin
         if debayer then begin
           j1:=max(j-1,0);
           j2:=j;
           j3:=min(j+1,xs-1);
           pix1:=round(fits.imageMin+fits.image[0,i1,j1]/fits.imageC);
           pix2:=round(fits.imageMin+fits.image[0,i1,j2]/fits.imageC);
           pix3:=round(fits.imageMin+fits.image[0,i1,j3]/fits.imageC);
           pix4:=round(fits.imageMin+fits.image[0,i2,j1]/fits.imageC);
           pix5:=round(fits.imageMin+fits.image[0,i2,j2]/fits.imageC);
           pix6:=round(fits.imageMin+fits.image[0,i2,j3]/fits.imageC);
           pix7:=round(fits.imageMin+fits.image[0,i3,j1]/fits.imageC);
           pix8:=round(fits.imageMin+fits.image[0,i3,j2]/fits.imageC);
           pix9:=round(fits.imageMin+fits.image[0,i3,j3]/fits.imageC);
           p^:=fits.BayerInterpolationExp(t,rmult,gmult,bmult,pix1,pix2,pix3,pix4,pix5,pix6,pix7,pix8,pix9,ii,j);
         end else begin
           // B/W image
           xx:=fits.imageMin+fits.image[0,i,j]/fits.imageC;
           x:=round(max(0,min(MaxWord,xx)));
           p^.red:=x;
           p^.green:=x;
           p^.blue:=x;
         end;
       end;
       p^.alpha:=65535;
       inc(p);
   end;
end;
working := False;
end;

//////////////////// TGetStarList /////////////////////////

constructor TGetStarList.Create(CreateSuspended: boolean);
begin
  FreeOnTerminate := false;
  inherited Create(CreateSuspended);
  working := True;
end;

procedure TGetStarList.Execute;
var
  i, j, starty, endy, ss, xs,ys: integer;
  fitsX,fitsY,fx,fy,nhfd,size,marginx,marginy: integer;
  hfd1,star_fwhm,vmax,bg,bgdev,xc,yc,snr,flux: double;
begin
  xs:= fits.Fwidth;
  ys:= fits.FHeight;
  // step size
  ss := ry div num div s;
  marginx:=(xs-rx)div 2 div s;
  marginy:=(ys-ry)div 2 div s;
  // range for current thread
  starty := marginy + id * ss;
  if id=(num-1) then
    endy := ((ys) div s)-marginy
  else
    endy := starty + ss;

  nhfd:=0;{set counters at zero}
  SetLength(StarList,1000);{allocate initial size}
  // process the rows range for this thread
  for fy:=starty to endy do { move test box with stepsize rs around}
   begin
     fitsY:=fy*s;
     for fx:=marginx to ((xs) div s)-marginx do
     begin
       fitsX:=fx*s;

       fits.GetHFD2(fitsX,fitsY,s+overlap,xc,yc,bg,bgdev,hfd1,star_fwhm,vmax,snr,flux,false);{2018-3-21, calculate HFD}

       {scale the result as GetHFD2 work with internal 16 bit values}
       vmax:=vmax/fits.imageC;
       bg:=bg/fits.imageC+fits.FimageMin;
       bgdev:=bgdev/fits.imageC;

       {check valid hfd }
       if ((hfd1>0)and (Undersampled or (hfd1>0.8)))
          and (hfd1<99)
          and (img_temp[0,round(xc),round(yc)]=0)  {area not surveyed}
          and (snr>AutofocusMinSNR)  {minimal star detection level, also detect saturation}
       then
       begin
         inc(nhfd);
         if nhfd>=Length(StarList) then
            SetLength(StarList,nhfd+1000);  {get more space to store values}
         StarList[nhfd-1].x:=xc;
         StarList[nhfd-1].y:=yc;
         StarList[nhfd-1].hfd:=hfd1;
         StarList[nhfd-1].fwhm:=star_fwhm;
         StarList[nhfd-1].snr:=snr;
         StarList[nhfd-1].vmax:=vmax;
         StarList[nhfd-1].bg:=bg;
         size:=round(2*hfd1);
         for j:=max(0,round(yc)-size) to min(ys-1,integer(round(yc))+size) do {mark the whole star area as surveyed}
            for i:=max(0,round(xc)-size) to min(xs-1,integer(round(xc))+size) do
               img_temp[0,i,j]:=1;

      end;
     end;
   end;
   SetLength(StarList,nhfd);  {set length to new number of elements}
   working:=false;
end;

//////////////////// TFits /////////////////////////

constructor TFits.Create(AOwner:TComponent);
begin
inherited Create(AOwner);
Fheight:=0;
Fwidth:=0;
ImgDmin:=0;
FBPMcount:=0;
FBPMProcess:=false;
FDarkProcess:=false;
FDarkOn:=false;
ImgDmax:=MaxWord;
FImgFullRange:=false;
FStreamValid:=false;
FImageValid:=false;
FMarkOverflow:=false;
FMaxADU:=MAXWORD;
FOverflow:=MAXWORD;
FUnderflow:=0;
FInvert:=false;
ClearFitsInfo;
FHeader:=TFitsHeader.Create;
FStream:=TMemoryStream.Create;
FIntfImg:=TLazIntfImage.Create(0,0);
emptybmp:=Tbitmap.Create;
emptybmp.SetSize(1,1);
SetGamma(1.0);
end;

destructor  TFits.Destroy; 
begin
try
setlength(imar64,0,0,0);
setlength(imar32,0,0,0);
setlength(imai8,0,0,0);
setlength(imai16,0,0,0);
setlength(imai32,0,0,0);
setlength(Fimage,0,0,0);
FHeader.Free;
FStream.Free;
FIntfImg.Free;
emptybmp.Free;
FreeDark;
inherited destroy;
except
//writeln('error destroy '+name);
end;
end;

procedure TFits.msg(txt: string; level:integer=3);
begin
 if Assigned(FonMsg) then FonMsg('FITS: '+txt,level);
end;

procedure TFits.SetVideoStream(value:TMemoryStream);
begin
// other header previously set by caller
ClearFitsInfo;
FImageValid:=false;
cur_axis:=1;
setlength(imar64,0,0,0);
setlength(imar32,0,0,0);
setlength(imai8,0,0,0);
setlength(imai16,0,0,0);
setlength(imai32,0,0,0);
setlength(Fimage,0,0,0);
FStream.Clear;
FStream.Position:=0;
value.Position:=0;
FStream.CopyFrom(value,value.Size);
Fhdr_end:=0;
ReadFitsImage;
end;

procedure TFits.SetStream(value:TMemoryStream);
begin
try
 FImageValid:=false;
 ClearFitsInfo;
 cur_axis:=1;
 setlength(imar64,0,0,0);
 setlength(imar32,0,0,0);
 setlength(imai8,0,0,0);
 setlength(imai16,0,0,0);
 setlength(imai32,0,0,0);
 setlength(Fimage,0,0,0);
 FStream.Clear;
 FStream.Position:=0;
 value.Position:=0;
 FStream.CopyFrom(value,value.Size);
 Fhdr_end:=FHeader.ReadHeader(FStream);
 FStreamValid:=true;
except
 ClearFitsInfo;
end;
end;

Procedure TFits.LoadStream;
begin
  GetFitsInfo;
  if FFitsInfo.valid then begin
    ReadFitsImage;
  end;
end;

function TFits.GetStream: TMemoryStream;
begin
  if not FStreamValid then begin
    WriteFitsImage;
    FStreamValid:=true;
  end;
  result:=FHeader.GetStream;
  FStream.Position:=Fhdr_end;
  result.CopyFrom(FStream,FStream.Size-Fhdr_end);
end;

procedure TFits.SaveToFile(fn: string; pack: boolean=false);
var mem: TMemoryStream;
    tmpf,rmsg: string;
    i: integer;
begin
  mem:=GetStream;
  if pack then begin
    tmpf:=slash(TmpDir)+'tmppack.fits';
    mem.SaveToFile(tmpf);
    i:=PackFits(tmpf,fn+'.fz',rmsg);
    if i<>0 then begin
      msg('fpack error '+inttostr(i)+': '+rmsg,1);
      msg('Saving file without compression',1);
      mem.SaveToFile(fn);
    end;
  end
  else begin
    mem.SaveToFile(fn);
  end;
  mem.Free;
end;

procedure TFits.LoadFromFile(fn:string);
var mem: TMemoryStream;
    pack: boolean;
    rmsg: string;
    i: integer;
begin
if FileExistsUTF8(fn) then begin
 mem:=TMemoryStream.Create;
 pack:=uppercase(ExtractFileExt(fn))='.FZ';
 try
   if pack then begin
     i:=UnpackFits(fn,mem,rmsg);
     if i<>0 then begin
       ClearImage;
       msg('funpack error '+inttostr(i)+': '+rmsg,1);
       exit;
     end;
   end
   else
     mem.LoadFromFile(fn);
   SetBPM(bpm,0,0,0,0);
   FDarkOn:=false;
   SetStream(mem);
   LoadStream;
 finally
   mem.free;
 end;
end
else begin
 ClearImage;
 msg(Format(rsFileNotFound, [fn]),1);
end;
end;

function TFits.GetStatistics: string;
var ff: string;
    x: double;
    i,maxh,maxp,sz,sz2,npx,median:integer;
begin
  if FFitsInfo.valid then begin
    if FFitsInfo.bitpix>0 then ff:=f0 else ff:=f6;
    sz:=Fwidth*Fheight;
    sz2:=sz div 2;
    result:=rsImageStatist+crlf;
    result:=Format(rsPixelCount, [result, blank+IntToStr(sz)+crlf]);
    // min, max
    result:=result+rsMin2+blank+FormatFloat(ff,FFitsInfo.dmin)+crlf;
    result:=result+rsMax+blank+FormatFloat(ff,FFitsInfo.dmax)+crlf;
    // mode, median
    median:=0; maxh:=0;  npx:=0; maxp:=0;
    for i:=0 to high(word) do begin
      npx:=npx+FHistogram[i]-1;
      if (median=0) and (npx>sz2) then
          median:=i;
      if FHistogram[i]>maxh then begin
          maxh:=FHistogram[i];
          maxp:=i;
      end;
    end;
    if maxh>0 then begin
      x:= FimageMin+maxp/FimageC;
      result:=result+rsMode+blank+FormatFloat(ff, x)+crlf;
    end;
    if median>0 then begin
      x:= FimageMin+median/FimageC;
      result:=Format(rsMedian, [result, blank+FormatFloat(ff, x)+crlf]);
    end;
    // mean
    result:=result+rsMean+blank+FormatFloat(f1, Fmean)+crlf;
    // sigma
    result:=result+rsStdDev+blank+FormatFloat(f1, Fsigma)+crlf;
  end
  else
    result:='';
end;

procedure TFits.ClearFitsInfo;
begin
with FFitsInfo do begin
   valid:=false; solved:=false; floatingpoint:=false;
   bitpix:=0; naxis:=0; naxis1:=0; naxis2:=0; naxis3:=1;
   Frx:=-1; Fry:=-1; Frwidth:=0; Frheight:=0; BinX:=1; BinY:=1;
   bzero:=0; bscale:=1; dmax:=0; dmin:=0; blank:=0;
   bayerpattern:='';
   bayeroffsetx:=0; bayeroffsety:=0;
   rmult:=0; gmult:=0; bmult:=0;
   equinox:=2000; ra:=NullCoord; dec:=NullCoord; crval1:=NullCoord; crval2:=NullCoord;
   pixsz1:=0; pixsz2:=0; pixratio:=1; focallen:=0; scale:=0;
   exptime:=0; airmass:=0;
   objects:=''; ctype1:=''; ctype2:='';
end;
end;

procedure TFits.GetFitsInfo;
var   i : integer;
      keyword,buf : string;
begin
 ClearFitsInfo;
 with FFitsInfo do begin
  for i:=0 to FHeader.Rows.Count-1 do begin
    keyword:=trim(FHeader.Keys[i]);
    buf:=trim(FHeader.Values[i]);
    if (keyword='SIMPLE') then if (copy(buf,1,1)<>'T')
       then begin valid:=false;Break;end
       else begin valid:=true;end;
    if (keyword='BITPIX') then bitpix:=strtoint(buf);
    if (keyword='NAXIS')  then naxis:=strtoint(buf);
    if (keyword='NAXIS1') then naxis1:=strtoint(buf);
    if (keyword='NAXIS2') then naxis2:=strtoint(buf);
    if (keyword='NAXIS3') then naxis3:=strtoint(buf);
    if (keyword='BZERO') then bzero:=strtofloat(buf);
    if (keyword='BSCALE') then bscale:=strtofloat(buf);
    if (keyword='DATAMAX') then dmax:=strtofloat(buf);
    if (keyword='DATAMIN') then dmin:=strtofloat(buf);
    if (keyword='THRESH') then dmax:=strtofloat(buf);
    if (keyword='THRESL') then dmin:=strtofloat(buf);
    if (keyword='BLANK') then blank:=strtofloat(buf);
    if (keyword='FOCALLEN') then focallen:=strtofloat(buf);
    if (keyword='EXPTIME') then exptime:=strtofloat(buf);
    if (keyword='XPIXSZ') then pixsz1:=strtofloat(buf);
    if (keyword='YPIXSZ') then pixsz2:=strtofloat(buf);
    if (keyword='XBINNING') then BinX:=round(StrToFloat(buf));
    if (keyword='YBINNING') then BinY:=round(StrToFloat(buf));
    if (keyword='FRAMEX') then Frx:=round(StrToFloat(buf));
    if (keyword='FRAMEY') then Fry:=round(StrToFloat(buf));
    if (keyword='FRAMEHGT') then Frheight:=round(StrToFloat(buf));
    if (keyword='FRAMEWDH') then Frwidth:=round(StrToFloat(buf));
    if (keyword='BAYERPAT') then bayerpattern:=trim(buf);
    if (keyword='XBAYROFF') then bayeroffsetx:=round(StrToFloat(buf));
    if (keyword='YBAYROFF') then bayeroffsety:=round(StrToFloat(buf));
    if (keyword='MULT_R') then rmult:=strtofloat(buf);
    if (keyword='MULT_G') then gmult:=strtofloat(buf);
    if (keyword='MULT_B') then bmult:=strtofloat(buf);
    if (keyword='AIRMASS') then airmass:=strtofloat(buf);
    if (keyword='OBJECT') then objects:=trim(buf);
    if (keyword='RA') then ra:=StrToFloatDef(buf,NullCoord);
    if (keyword='DEC') then dec:=StrToFloatDef(buf,NullCoord);
    if (keyword='EQUINOX') then equinox:=StrToFloatDef(buf,2000);
    if (keyword='CTYPE1') then ctype1:=buf;
    if (keyword='CTYPE2') then ctype2:=buf;
    if (keyword='CRVAL1') then crval1:=strtofloat(buf);
    if (keyword='CRVAL2') then crval2:=strtofloat(buf);
    if (keyword='SCALE')  then scale:=strtofloat(buf);
    if (scale=0) and (keyword='SECPIX1')then scale:=strtofloat(buf);
    if (keyword='A_ORDER') or
       (keyword='AMDX1') or
       (keyword='CD1_1')
        then solved:=true; // the image must be astrometry solved.
 end;
 if (pixsz1<>0)and(pixsz2<>0) then pixratio:=pixsz1/pixsz2;
 valid:=valid and (naxis>0); // do not process file without primary array
 if not valid then exit;
 floatingpoint:=bitpix<0;
 // very crude coordinates to help astrometry if telescope is not available
 if ra=NullCoord then begin
   if (copy(ctype1,1,3)='RA-')and(crval1<>NullCoord) then
      ra:=crval1/15;
 end;
 if dec=NullCoord then begin
   if (copy(ctype2,1,4)='DEC-')and(crval2<>NullCoord) then
      dec:=crval2;
 end;
 // remove unsupported ASCOM SensorType for debayering. Correct SensorType is still written in header for further processing
 if (bayerpattern='CMYG') or
    (bayerpattern='CMYG2') or
    (bayerpattern='LRGB')
    then
      bayerpattern:='UNSUPPORTED';
 // set color image type
 colormode:=1;
 if (naxis=3)and(naxis1=3) then begin // contiguous color RGB
  naxis1:=naxis2;
  naxis2:=naxis3;
  naxis3:=3;
  colormode:=2;
 end;
 if (naxis=3)and(naxis1=4) then begin // contiguous color RGBA
  naxis1:=naxis2;
  naxis2:=naxis3;
  naxis3:=3;
  colormode:=3;
 end;
 if (naxis=3)and(naxis3=3) then n_axis:=3 else n_axis:=1;
end;
end;

Procedure TFits.ReadFitsImage;
var i,ii,j,npix,k,km,kk : integer;
    x,dmin,dmax : double;
    ni,sum,sum2 : extended;
    x16,b16:smallint;
    x8,b8:byte;
begin
{$ifdef debug_raw}writeln(FormatDateTime(dateiso,Now)+blank+'ReadFitsImage');{$endif}
FImageValid:=false;
if FFitsInfo.naxis1=0 then exit;
FDarkProcess:=false;
FBPMProcess:=false;
dmin:=1.0E100;
dmax:=-1.0E100;
sum:=0; sum2:=0; ni:=0;
if n_axis=3 then cur_axis:=1
else begin
  cur_axis:=trunc(min(cur_axis,FFitsInfo.naxis3));
  cur_axis:=trunc(max(cur_axis,1));
end;
if (FFitsInfo.naxis1>maxl)or(FFitsInfo.naxis2>maxl) then
  raise exception.Create(Format('Image too big! limit is currently %dx%d %sPlease open an issue to request an extension.',[maxl,maxl,crlf]));
Fheight:=FFitsInfo.naxis2;
Fwidth :=FFitsInfo.naxis1;
FStream.Position:=0;
case FFitsInfo.bitpix of
  -64 : begin
        setlength(imar64,n_axis,Fheight,Fwidth);
        FStream.Seek(Fhdr_end+FFitsInfo.naxis2*FFitsInfo.naxis1*8*(cur_axis-1),soFromBeginning);
        end;
  -32 : begin
        setlength(imar32,n_axis,Fheight,Fwidth);
        FStream.Seek(Fhdr_end+FFitsInfo.naxis2*FFitsInfo.naxis1*4*(cur_axis-1),soFromBeginning);
        end;
    8 : begin
        setlength(imai8,n_axis,Fheight,Fwidth);
        FStream.Seek(Fhdr_end+FFitsInfo.naxis2*FFitsInfo.naxis1*(cur_axis-1),soFromBeginning);
        end;
   16 : begin
        setlength(imai16,n_axis,Fheight,Fwidth);
        FStream.Seek(Fhdr_end+FFitsInfo.naxis2*FFitsInfo.naxis1*2*(cur_axis-1),soFromBeginning);
        end;
   32 : begin
        setlength(imai32,n_axis,Fheight,Fwidth);
        FStream.Seek(Fhdr_end+FFitsInfo.naxis2*FFitsInfo.naxis1*4*(cur_axis-1),soFromBeginning);
        end;
end;
npix:=0;
b8:=round(FFitsInfo.blank);
b16:=round(FFitsInfo.blank);
case FFitsInfo.bitpix of
    -64:for k:=cur_axis-1 to cur_axis+n_axis-2 do begin
        for i:=0 to FFitsInfo.naxis2-1 do begin
         ii:=FFitsInfo.naxis2-1-i;
         for j := 0 to FFitsInfo.naxis1-1 do begin
           if (npix mod 360 = 0) then begin
             FStream.Read(d64,sizeof(d64));
             npix:=0;
           end;
           inc(npix);
           x:=InvertF64(d64[npix]);
           if x=FFitsInfo.blank then x:=0;
           imar64[k,ii,j] := x ;
           x:=FFitsInfo.bzero+FFitsInfo.bscale*x;
           dmin:=min(x,dmin);
           dmax:=max(x,dmax);
           sum:=sum+x;
           sum2:=sum2+x*x;
           ni:=ni+1;
          end;
         end;
         end;
    -32: for k:=cur_axis-1 to cur_axis+n_axis-2 do begin
        for i:=0 to FFitsInfo.naxis2-1 do begin
         ii:=FFitsInfo.naxis2-1-i;
         for j := 0 to FFitsInfo.naxis1-1 do begin
           if (npix mod 720 = 0) then begin
             FStream.Read(d32,sizeof(d32));
             npix:=0;
           end;
           inc(npix);
           x:=InvertF32(d32[npix]);
           if x=FFitsInfo.blank then x:=0;
           imar32[k,ii,j] := x ;
           x:=FFitsInfo.bzero+FFitsInfo.bscale*x;
           dmin:=min(x,dmin);
           dmax:=max(x,dmax);
           sum:=sum+x;
           sum2:=sum2+x*x;
           ni:=ni+1;
         end;
         end;
         end;
     8 : if colormode=1 then
        for k:=cur_axis-1 to cur_axis+n_axis-2 do begin
        for i:=0 to FFitsInfo.naxis2-1 do begin
         ii:=FFitsInfo.naxis2-1-i;
         for j := 0 to FFitsInfo.naxis1-1 do begin
           if (npix mod 2880 = 0) then begin
             FStream.Read(d8,sizeof(d8));
             npix:=0;
           end;
           inc(npix);
           x8:=d8[npix];
           if x8=b8 then x8:=0;
           imai8[k,ii,j] := x8;
           x:=FFitsInfo.bzero+FFitsInfo.bscale*x8;
           dmin:=min(x,dmin);
           dmax:=max(x,dmax);
           sum:=sum+x;
           sum2:=sum2+x*x;
           ni:=ni+1;
         end;
         end;
         end else begin
          kk:=0;
          if colormode=3 then begin  // output RGB from RGBA
             n_axis:=4;
             kk:=1;
          end;
          for i:=0 to FFitsInfo.naxis2-1 do begin
           ii:=FFitsInfo.naxis2-1-i;
           for j := 0 to FFitsInfo.naxis1-1 do begin
             for k:=cur_axis+n_axis-2 downto cur_axis-1 do begin
             if (npix mod 2880 = 0) then begin
               FStream.Read(d8,sizeof(d8));
               npix:=0;
             end;
             inc(npix);
             km:=k-kk;
             if km<0 then continue; // skip A
             x8:=d8[npix];
             if x8=b8 then x8:=0;
             imai8[km,ii,j] := x8;
             x:=FFitsInfo.bzero+FFitsInfo.bscale*x8;
             dmin:=min(x,dmin);
             dmax:=max(x,dmax);
             sum:=sum+x;
             sum2:=sum2+x*x;
             ni:=ni+1;
             end;
           end;
          end;
          if colormode=3 then n_axis:=3; // restore value
         end;

     16 : for k:=cur_axis-1 to cur_axis+n_axis-2 do begin
        for i:=0 to FFitsInfo.naxis2-1 do begin
         ii:=FFitsInfo.naxis2-1-i;
         for j := 0 to FFitsInfo.naxis1-1 do begin
           if (npix mod 1440 = 0) then begin
             FStream.Read(d16,sizeof(d16));
             npix:=0;
           end;
           inc(npix);
           x16:=BEtoN(d16[npix]);
           if x16=b16 then x16:=0;
           imai16[k,ii,j] := x16;
           x:=FFitsInfo.bzero+FFitsInfo.bscale*x16;
           dmin:=min(x,dmin);
           dmax:=max(x,dmax);
           sum:=sum+x;
           sum2:=sum2+x*x;
           ni:=ni+1;
         end;
         end;
         end;
     32 : for k:=cur_axis-1 to cur_axis+n_axis-2 do begin
        for i:=0 to FFitsInfo.naxis2-1 do begin
         ii:=FFitsInfo.naxis2-1-i;
         for j := 0 to FFitsInfo.naxis1-1 do begin
           if (npix mod 720 = 0) then begin
             FStream.Read(d32,sizeof(d32));
             npix:=0;
           end;
           inc(npix);
           x:=BEtoN(LongInt(d32[npix]));
           if x=FFitsInfo.blank then x:=0;
           imai32[k,ii,j] := round(x);
           x:=FFitsInfo.bzero+FFitsInfo.bscale*x;
           dmin:=min(x,dmin);
           dmax:=max(x,dmax);
           sum:=sum+x;
           sum2:=sum2+x*x;
           ni:=ni+1;
         end;
         end;
         end;
end;
FStreamValid:=true;
Fmean:=sum/ni;
Fsigma:=sqrt( (sum2/ni)-(Fmean*Fmean) );
if dmin>=dmax then begin
   if dmin=0 then
     dmax:=dmin+1
   else
     dmin:=dmax-1;
end;
if (FFitsInfo.dmin=0)and(FFitsInfo.dmax=0) then begin
  FFitsInfo.dmin:=dmin;
  FFitsInfo.dmax:=dmax;
end;
SetLength(FStarList,0); {reset object list}
{$ifdef debug_raw}writeln(FormatDateTime(dateiso,Now)+blank+'GetImage');{$endif}
GetImage;
{$ifdef debug_raw}writeln(FormatDateTime(dateiso,Now)+blank+'GetImage end');{$endif}
FImageValid:=true;
end;

Procedure TFits.WriteFitsImage;
var hdrmem: TMemoryStream;
    i,j,k,ii,npix: integer;
    first:boolean;
begin
  hdrmem:=FHeader.GetStream;
  Fhdr_end:=hdrmem.Size;
  FStream.Clear;
  FStream.Position:=0;
  hdrmem.Position:=0;
  FStream.CopyFrom(hdrmem,Fhdr_end);
  hdrmem.Free;
  npix:=0;
  first:=true;
  case FFitsInfo.bitpix of
     8 : begin
          for k:=cur_axis-1 to cur_axis+n_axis-2 do begin
          for i:=0 to FFitsInfo.naxis2-1 do begin
           ii:=FFitsInfo.naxis2-1-i;
           for j := 0 to FFitsInfo.naxis1-1 do begin
             if (npix mod 1440 = 0) then begin
               if not first then FStream.Write(d8,sizeof(d8));
               FillWord(d8,sizeof(d8),0);
               npix:=0;
               first:=false;
             end;
             inc(npix);
             d8[npix]:=imai8[k,ii,j];
           end;
           end;
           end;
           if npix>0 then  FStream.Write(d8,sizeof(d8));
           end;
     16 : begin
          for k:=cur_axis-1 to cur_axis+n_axis-2 do begin
          for i:=0 to FFitsInfo.naxis2-1 do begin
           ii:=FFitsInfo.naxis2-1-i;
           for j := 0 to FFitsInfo.naxis1-1 do begin
             if (npix mod 1440 = 0) then begin
               if not first then FStream.Write(d16,sizeof(d16));
               FillWord(d16,sizeof(d16),0);
               npix:=0;
               first:=false;
             end;
             inc(npix);
             d16[npix]:=NtoBE(imai16[k,ii,j]);
           end;
           end;
           end;
           if npix>0 then  FStream.Write(d16,sizeof(d16));
           end;
     32 : begin
          for k:=cur_axis-1 to cur_axis+n_axis-2 do begin
          for i:=0 to FFitsInfo.naxis2-1 do begin
           ii:=FFitsInfo.naxis2-1-i;
           for j := 0 to FFitsInfo.naxis1-1 do begin
             if (npix mod 1440 = 0) then begin
               if not first then FStream.Write(d32,sizeof(d32));
               FillWord(d32,sizeof(d32),0);
               npix:=0;
               first:=false;
             end;
             inc(npix);
             d32[npix]:=NtoBE(imai32[k,ii,j]);
           end;
           end;
           end;
           if npix>0 then  FStream.Write(d32,sizeof(d32));
           end;
  end;
end;

procedure TFits.GetImage;
var i,j: integer;
    c: double;
    working, timingout: boolean;
    timelimit: TDateTime;
    thread: array[0..15] of TGetImage;
    tc,timeout: integer;
begin
  if FImgFullRange then begin
    Fdmin:=0;
    if FFitsInfo.bitpix=8 then
      Fdmax:=MaxByte
    else
      Fdmax:=MaxWord;
  end else begin
    Fdmin:=FFitsInfo.dmin;
    Fdmax:=FFitsInfo.dmax;
  end;
  setlength(Fimage,n_axis,Fheight,Fwidth);
  for i:=0 to high(word) do FHistogram[i]:=1; // minimum 1 to take the log

  if Fdmax>Fdmin then
    c:=MaxWord/(Fdmax-Fdmin)
  else
    c:=1;
  FimageC:=c;
  FimageMin:=Fdmin;
  FimageMax:=Fdmax;
  if FimageMin<0 then FimageMin:=0;
  thread[0]:=nil;
  // number of thread
   tc := max(1,min(16, MaxThreadCount)); // based on number of core
   tc := max(1,min(tc,Fheight div 100)); // do not split the image too much
  // start thread
  for i := 0 to tc - 1 do
  begin
    thread[i] := TGetImage.Create(True);
    thread[i].fits := self;
    thread[i].num := tc;
    thread[i].id := i;
    thread[i].c := c;
    thread[i].Fdmin := Fdmin;
    thread[i].Start;
  end;
  // wait complete
  timeout:=60;
  timelimit := now + timeout / secperday;
  repeat
    sleep(100);
    working := False;
    for i := 0 to tc - 1 do
      working := working or thread[i].working;
    timingout := (now > timelimit);
  until (not working) or timingout;
  // total histogram
  for i:=0 to tc - 1 do begin
    for j:=0 to high(word) do begin
       FHistogram[j]:=FHistogram[j]+thread[i].hist[j];
    end;
  end;
  // cleanup
  for i := 0 to tc - 1 do thread[i].Free;
end;

procedure TFits.FreeDark;
begin
  if FDark<>nil then FreeAndNil(FDark);
end;

procedure TFits.ApplyDark;
begin
if (FDarkOn)and(FDark<>nil)and(SameFormat(FDark))
   then begin
    {$ifdef debug_raw}writeln(FormatDateTime(dateiso,Now)+blank+'apply dark');{$endif}
     Math(FDark,moSub);
     FDarkProcess:=true;
     FHeader.Insert( FHeader.Indexof('END'),'COMMENT','Dark substracted','');
   end;
end;

procedure TFits.ApplyBPM;
var i,x,y,x0,y0: integer;
begin
if (FBPMcount>0)and(FBPMnax=FFitsInfo.naxis) then begin
  {$ifdef debug_raw}writeln(FormatDateTime(dateiso,Now)+blank+'apply BPM');{$endif}
  if not FImageValid then LoadStream;
  if (FFitsInfo.Frwidth>0)and(FFitsInfo.Frheight>0)and(FFitsInfo.Frx>=0)and(FFitsInfo.Fry>=0) then begin
    x0:=FFitsInfo.Frx;
    y0:=FBPMny-FFitsInfo.Fry-FFitsInfo.Frheight;
  end else begin
    x0:=0;
    y0:=0;
  end;
  for i:=1 to FBPMcount do begin
    x:=Fbpm[i,1]-x0;
    y:=Fbpm[i,2]-y0;
    if (x>0)and(x<Fwidth-2)and(y>0)and(y<Fheight-2) then begin
      image[0,y,x]:=(image[0,y-1,x]+image[0,y+1,x]+image[0,y,x-1]+image[0,y,x+1]) div 4;
      if n_axis=3 then begin
        image[1,y,x]:=(image[1,y-1,x]+image[1,y+1,x]+image[1,y,x-1]+image[1,y,x+1]) div 4;
        image[2,y,x]:=(image[2,y-1,x]+image[2,y+1,x]+image[2,y,x-1]+image[2,y,x+1]) div 4;
      end;
    end;
  end;
  FBPMProcess:=true;
  FHeader.Insert( FHeader.Indexof('END'),'COMMENT','Corrected with Bap Pixel Map','');
end;
end;

procedure TFits.SetBPM(value: TBpm; count,nx,ny,nax:integer);
var i:integer;
begin
 for i:=1 to count do begin
    Fbpm[i,1]:=value[i,1];
    Fbpm[i,2]:=value[i,2];
 end;
 FBPMcount:=count;
 FBPMnx:=nx;
 FBPMny:=ny;
 FBPMnax:=nax;
end;

function TFits.GetHasBPM: boolean;
begin
  result:=FBPMcount>0;
end;

procedure TFits.SetImgFullRange(value: boolean);
begin
  FImgFullRange:=value;
  if (Fheight>0)and(Fwidth>0) then GetImage;
end;

function TFits.GammaCorr(value: Word):byte;
begin
  // gamma_c is 0..1 of length 32768
  // value is 0..65535
  // result is 0..255
  result:=round(255*gamma_c[trunc(value/2)]);
  if FInvert then result:=255-result;
end;

procedure TFits.SetGamma(value: single);
var
  i: integer;
begin
  if value<>FGamma then begin
    FGamma:=value;
    for i:=0 to 32768 do
      gamma_c[i]:=power(i/32768.0, gamma);
  end;
end;

function TFits.GetBayerMode: TBayerMode;
var buf: string;
begin
  if DefaultBayerMode=bayerCamera then begin
    buf:=copy(HeaderInfo.bayerpattern,1,2);
    // use value from header
    if buf='GR' then result:=bayerGR
    else if buf='RG' then result:=bayerRG
    else if buf='T'  then result:=bayerRG  //some software can use a boolean to indicate a bayered image
    else if buf=''   then result:=bayerRG  //this is the most probable case if a user request auto debayer with a camera that not report it's sensor type
    else if buf='BG' then result:=bayerBG
    else if buf='GB' then result:=bayerGB
    else if buf='UN' then result:=bayerUnsupported
    else
      result:=bayerUnsupported;
  end
  else begin
    // use default configured value
    result:=DefaultBayerMode;
  end;
end;

function TFits.BayerInterpolationExp(t:TBayerMode; rmult,gmult,bmult:double; pix1,pix2,pix3,pix4,pix5,pix6,pix7,pix8,pix9:integer; row,col:integer):TExpandedPixel; inline;
var r,g,b: integer;
begin
   if not odd(row) then begin //ligne paire
      if not odd(col) then begin //colonne paire et ligne paire
        case t of
        bayerGR: begin
            r:= round(rmult*(pix4+pix6)/2);
            g:=round(gmult*pix5);
            b:= round(bmult*(pix2+pix8)/2);
           end;
        bayerRG: begin
            r:=round(rmult*pix5);
            g:= round(gmult*(pix2+pix4+pix6+pix8)/4);
            b:= round(bmult*(pix1+pix3+pix7+pix9)/4);
           end;
        bayerBG: begin
            r:= round(rmult*(pix1+pix3+pix7+pix9)/4);
            g:= round(gmult*(pix2+pix4+pix6+pix8)/4);
            b:=round(bmult*pix5);
           end;
        bayerGB: begin
            r:= round(rmult*(pix2+pix8)/2);
            g:=round(gmult*pix5);
            b:= round(bmult*(pix4+pix6)/2);
           end;
        else begin
            r:=0; g:=0; b:=0;
           end;
        end;
      end
      else begin //colonne impaire et ligne paire
       case t of
       bayerGR: begin
           r:=round(rmult*pix5);
           g:= round(gmult*(pix2+pix4+pix6+pix8)/4);
           b:= round(bmult*(pix1+pix3+pix7+pix9)/4);
          end;
       bayerRG: begin
           r:= round(rmult*(pix4+pix6)/2);
           g:=round(gmult*pix5);
           b:=round(bmult*(pix2+pix8)/2);
          end;
       bayerBG: begin
           r:=round(rmult*(pix2+pix8)/2);
           g:=round(gmult*pix5);
           b:= round(bmult*(pix4+pix6)/2);
          end;
       bayerGB: begin
           r:= round(rmult*(pix1+pix3+pix7+pix9)/4);
           g:= round(gmult*(pix2+pix4+pix6+pix8)/4);
           b:=round(bmult*pix5);
          end;
       else begin
           r:=0; g:=0; b:=0;
          end;
       end;
     end;
   end
   else begin //ligne impaire
     if not odd(col) then begin //colonne paire et ligne impaire
       case t of
       bayerGR: begin
           r:= round(rmult*(pix1+pix3+pix7+pix9)/4);
           g:= round(gmult*(pix2+pix4+pix6+pix8)/4);
           b:=round(bmult*pix5);
          end;
       bayerRG: begin
           r:= round(rmult*(pix2+pix8)/2);
           g:=round(gmult*pix5);
           b:=round(bmult*(pix4+pix6)/2);
          end;
       bayerBG: begin
           r:= round(rmult*(pix4+pix6)/2);
           g:=round(gmult*pix5);
           b:=round(bmult*(pix2+pix8)/2);
          end;
       bayerGB: begin
           r:=round(rmult*pix5);
           g:= round(gmult*(pix2+pix4+pix6+pix8)/4);
           b:= round(bmult*(pix1+pix3+pix7+pix9)/4);
          end;
       else begin
           r:=0; g:=0; b:=0;
          end;
       end;
    end
    else begin //colonne impaire et ligne impaire
       case t of
       bayerGR: begin
           r:= round(rmult*(pix2+pix8)/2);
           g:= round(gmult*pix5);
           b:= round(bmult*(pix4+pix6)/2);
          end;
       bayerRG: begin
           r:= round(rmult*(pix1+pix3+pix7+pix9)/4);
           g:= round(gmult*(pix2+pix4+pix6+pix8)/4);
           b:=round(bmult*pix5);
          end;
       bayerBG: begin
           r:= round(rmult*pix5);
           g:= round(gmult*(pix2+pix4+pix6+pix8)/4);
           b:= round(bmult*(pix1+pix3+pix7+pix9)/4);
          end;
       bayerGB: begin
           r:= round(rmult*(pix4+pix6)/2);
           g:= round(gmult*pix5);
           b:= round(bmult*(pix2+pix8)/2);
          end;
       else begin
           r:=0; g:=0; b:=0;
          end;
       end;
     end;
   end;
   result.red:=max(0,min(MAXWORD,r));
   result.green:=max(0,min(MAXWORD,g));
   result.blue:= max(0,min(MAXWORD,b));
end;

function TFits.BayerInterpolation(t:TBayerMode; rmult,gmult,bmult:double; pix1,pix2,pix3,pix4,pix5,pix6,pix7,pix8,pix9:integer; row,col:integer):TBGRAPixel; inline;
var r,g,b: integer;
    l,lg: word;
begin
   if not odd(row) then begin //ligne paire
      if not odd(col) then begin //colonne paire et ligne paire
        case t of
        bayerGR: begin
            r:= round(rmult*(pix4+pix6)/2);
            g:=round(gmult*pix5);
            b:= round(bmult*(pix2+pix8)/2);
           end;
        bayerRG: begin
            r:=round(rmult*pix5);
            g:= round(gmult*(pix2+pix4+pix6+pix8)/4);
            b:= round(bmult*(pix1+pix3+pix7+pix9)/4);
           end;
        bayerBG: begin
            r:= round(rmult*(pix1+pix3+pix7+pix9)/4);
            g:= round(gmult*(pix2+pix4+pix6+pix8)/4);
            b:=round(bmult*pix5);
           end;
        bayerGB: begin
            r:= round(rmult*(pix2+pix8)/2);
            g:=round(gmult*pix5);
            b:= round(bmult*(pix4+pix6)/2);
           end;
        else begin
            r:=0; g:=0; b:=0;
           end;
        end;
      end
      else begin //colonne impaire et ligne paire
       case t of
       bayerGR: begin
           r:=round(rmult*pix5);
           g:= round(gmult*(pix2+pix4+pix6+pix8)/4);
           b:= round(bmult*(pix1+pix3+pix7+pix9)/4);
          end;
       bayerRG: begin
           r:= round(rmult*(pix4+pix6)/2);
           g:=round(gmult*pix5);
           b:=round(bmult*(pix2+pix8)/2);
          end;
       bayerBG: begin
           r:=round(rmult*(pix2+pix8)/2);
           g:=round(gmult*pix5);
           b:= round(bmult*(pix4+pix6)/2);
          end;
       bayerGB: begin
           r:= round(rmult*(pix1+pix3+pix7+pix9)/4);
           g:= round(gmult*(pix2+pix4+pix6+pix8)/4);
           b:=round(bmult*pix5);
          end;
       else begin
           r:=0; g:=0; b:=0;
          end;
       end;
     end;
   end
   else begin //ligne impaire
     if not odd(col) then begin //colonne paire et ligne impaire
       case t of
       bayerGR: begin
           r:= round(rmult*(pix1+pix3+pix7+pix9)/4);
           g:= round(gmult*(pix2+pix4+pix6+pix8)/4);
           b:=round(bmult*pix5);
          end;
       bayerRG: begin
           r:= round(rmult*(pix2+pix8)/2);
           g:=round(gmult*pix5);
           b:=round(bmult*(pix4+pix6)/2);
          end;
       bayerBG: begin
           r:= round(rmult*(pix4+pix6)/2);
           g:=round(gmult*pix5);
           b:=round(bmult*(pix2+pix8)/2);
          end;
       bayerGB: begin
           r:=round(rmult*pix5);
           g:= round(gmult*(pix2+pix4+pix6+pix8)/4);
           b:= round(bmult*(pix1+pix3+pix7+pix9)/4);
          end;
       else begin
           r:=0; g:=0; b:=0;
          end;
       end;
    end
    else begin //colonne impaire et ligne impaire
       case t of
       bayerGR: begin
           r:= round(rmult*(pix2+pix8)/2);
           g:= round(gmult*pix5);
           b:= round(bmult*(pix4+pix6)/2);
          end;
       bayerRG: begin
           r:= round(rmult*(pix1+pix3+pix7+pix9)/4);
           g:= round(gmult*(pix2+pix4+pix6+pix8)/4);
           b:=round(bmult*pix5);
          end;
       bayerBG: begin
           r:= round(rmult*pix5);
           g:= round(gmult*(pix2+pix4+pix6+pix8)/4);
           b:= round(bmult*(pix1+pix3+pix7+pix9)/4);
          end;
       bayerGB: begin
           r:= round(rmult*(pix4+pix6)/2);
           g:= round(gmult*pix5);
           b:= round(bmult*(pix2+pix8)/2);
          end;
       else begin
           r:=0; g:=0; b:=0;
          end;
       end;
     end;
   end;
   l:=max(0,min(MAXWORD,maxvalue([r,b,g])));
   if l>0 then begin
     lg:=GammaCorr(l);
     result.red:=max(0,min(MAXBYTE,round(r*lg/l)));
     result.green:=max(0,min(MAXBYTE,round(g*lg/l)));
     result.blue:= max(0,min(MAXBYTE,round(b*lg/l)));
   end
   else begin
     result.red:=0;
     result.green:=0;
     result.blue:= 0;
   end;
end;

procedure TFits.GetExpBitmap(var bgra: TExpandedBitmap; debayer:boolean);
// get linear 16bit bitmap
var i: integer;
    rmult,gmult,bmult,mx: double;
    t:TBayerMode;
    working, timingout: boolean;
    timelimit: TDateTime;
    thread: array[0..15] of TGetExpThread;
    tc,timeout: integer;
begin
rmult:=0; gmult:=0; bmult:=0;
t:=GetBayerMode;
if t=bayerUnsupported then debayer:=false;
if debayer then begin
  if (BalanceFromCamera)and(FFitsInfo.rmult>0)and(FFitsInfo.gmult>0)and(FFitsInfo.bmult>0) then begin
     rmult:=FFitsInfo.rmult;
     gmult:=FFitsInfo.gmult;
     bmult:=FFitsInfo.bmult;
  end else begin
     mx:=minvalue([RedBalance,GreenBalance,BlueBalance]);
     rmult:=RedBalance/mx;
     gmult:=GreenBalance/mx;
     bmult:=BlueBalance/mx;
  end;
  if (FFitsInfo.bayeroffsetx mod 2) = 1 then begin
    case t of
      bayerGR: t:=bayerRG;
      bayerRG: t:=bayerGR;
      bayerBG: t:=bayerGB;
      bayerGB: t:=bayerBG;
    end;
  end;
  if (FFitsInfo.bayeroffsety mod 2) = 1 then begin
    case t of
      bayerGR: t:=bayerBG;
      bayerRG: t:=bayerGB;
      bayerBG: t:=bayerGR;
      bayerGB: t:=bayerRG;
    end;
  end;
end;
bgra.SetSize(Fwidth,Fheight);
thread[0]:=nil;
// number of thread
 tc := max(1,min(16, MaxThreadCount)); // based on number of core
 tc := max(1,min(tc,Fheight div 100)); // do not split the image too much
// start thread
for i := 0 to tc - 1 do
begin
  thread[i] := TGetExpThread.Create(True);
  thread[i].fits := self;
  thread[i].num := tc;
  thread[i].id := i;
  thread[i].debayer := debayer;
  thread[i].rmult := rmult;
  thread[i].gmult := gmult;
  thread[i].bmult := bmult;
  thread[i].t := t;
  thread[i].bgra := bgra;
  thread[i].Start;
end;
// wait complete
timeout:=60;
timelimit := now + timeout / secperday;
repeat
  sleep(100);
  working := False;
  for i := 0 to tc - 1 do
    working := working or thread[i].working;
  timingout := (now > timelimit);
until (not working) or timingout;
// refresh image
bgra.InvalidateBitmap;
end;

procedure TFits.GetBGRABitmap(var bgra: TBGRABitmap; debayer:boolean);
// get stretched 8bit bitmap
var i : integer;
    HighOverflow,LowOverflow: TBGRAPixel;
    c,overflow,underflow: double;
    rmult,gmult,bmult,mx: double;
    t: TBayerMode;
    working, timingout: boolean;
    timelimit: TDateTime;
    thread: array[0..15] of TGetBgraThread;
    tc,timeout: integer;
begin
  rmult:=0; gmult:=0; bmult:=0;
  t:=GetBayerMode;
  if t=bayerUnsupported then debayer:=false;
  if debayer then begin
     if (BalanceFromCamera)and(FFitsInfo.rmult>0)and(FFitsInfo.gmult>0)and(FFitsInfo.bmult>0) then begin
       rmult:=FFitsInfo.rmult;
       gmult:=FFitsInfo.gmult;
       bmult:=FFitsInfo.bmult;
     end else begin
       mx:=minvalue([RedBalance,GreenBalance,BlueBalance]);
       rmult:=RedBalance/mx;
       gmult:=GreenBalance/mx;
       bmult:=BlueBalance/mx;
     end;
     if (FFitsInfo.bayeroffsetx mod 2) = 1 then begin
       case t of
         bayerGR: t:=bayerRG;
         bayerRG: t:=bayerGR;
         bayerBG: t:=bayerGB;
         bayerGB: t:=bayerBG;
       end;
     end;
     if (FFitsInfo.bayeroffsety mod 2) = 1 then begin
       case t of
         bayerGR: t:=bayerBG;
         bayerRG: t:=bayerGB;
         bayerBG: t:=bayerGR;
         bayerGB: t:=bayerRG;
       end;
     end;
  end;
  HighOverflow:=ColorToBGRA(clFuchsia);
  LowOverflow:=ColorToBGRA(clYellow);
  overflow:=(FOverflow-FimageMin)*FimageC;
  underflow:=(FUnderflow-FimageMin)*FimageC;
  bgra.SetSize(Fwidth,Fheight);
  if FImgDmin>=FImgDmax then FImgDmax:=FImgDmin+1;
  c:=MaxWord/(FImgDmax-FImgDmin);
  thread[0]:=nil;
  // number of thread
   tc := max(1,min(16, MaxThreadCount)); // based on number of core
   tc := max(1,min(tc,Fheight div 100)); // do not split the image too much
  // start thread
  for i := 0 to tc - 1 do
  begin
    thread[i] := TGetBgraThread.Create(True);
    thread[i].fits := self;
    thread[i].num := tc;
    thread[i].id := i;
    thread[i].debayer := debayer;
    thread[i].rmult := rmult;
    thread[i].gmult := gmult;
    thread[i].bmult := bmult;
    thread[i].t := t;
    thread[i].HighOverflow := HighOverflow;
    thread[i].LowOverflow := LowOverflow;
    thread[i].overflow := overflow;
    thread[i].underflow := underflow;
    thread[i].bgra := bgra;
    thread[i].FImgDmin := FImgDmin;
    thread[i].c := c;
    thread[i].Start;
  end;
  // wait complete
  timeout:=60;
  timelimit := now + timeout / secperday;
  repeat
    sleep(100);
    working := False;
    for i := 0 to tc - 1 do
      working := working or thread[i].working;
    timingout := (now > timelimit);
  until (not working) or timingout;
  // refresh image
  bgra.InvalidateBitmap;
end;

procedure TFits.SaveToBitmap(fn: string);
var expbmp: TExpandedBitmap;
    bgra: TBGRABitmap;
    ext: string;
begin
  ext:=uppercase(ExtractFileExt(fn));
  if (ext='.PNG')or(ext='.TIF')or(ext='.TIFF') then begin
    // save 16 bit linear image
    expbmp:=TExpandedBitmap.Create;
    GetExpBitmap(expbmp,FFitsInfo.bayerpattern<>'');
    expbmp.SaveToFile(fn);
    expbmp.Free;
  end
  else begin
    //save 8 bit stretched image
    bgra:=TBGRABitmap.Create;
    GetBGRABitmap(bgra,FFitsInfo.bayerpattern<>'');
    bgra.SaveToFile(fn);
    bgra.Free;
  end;
end;

procedure TFits.ClearImage;
begin
FImageValid:=false;
Fheight:=0;
Fwidth:=0;
ClearFitsInfo;
setlength(imar64,0,0,0);
setlength(imar32,0,0,0);
setlength(imai8,0,0,0);
setlength(imai16,0,0,0);
setlength(imai32,0,0,0);
setlength(Fimage,0,0,0);
FStream.Clear;
end;

function TFits.double_star(ri, x,y : integer):boolean;
// double star detection based difference bright_spot and center_of_gravity
var SumVal,SumValX,SumValY,val,vmax,bg, Xg, Yg: double;
     i,j : integer;
begin
  try
  // New background from corner values
  bg:=0;
  for i:=-ri+1 to ri do {calculate average background at the square boundaries of region of interest}
  begin
    bg:=bg+Fimage[0,y+ri,x+i];{top line, left to right}
    bg:=bg+Fimage[0,y+i,x+ri];{right line, top to bottom}
    bg:=bg+Fimage[0,y-ri,x-i];{bottom line, right to left}
    bg:=bg+Fimage[0,y-i,x-ri];{right line, bottom to top}
  end;
  bg:=bg/(8*ri);
  bg:=FimageMin+bg/FimageC;

  SumVal:=0;
  SumValX:=0;
  SumValY:=0;
  vmax:=0;
  for i:=-ri to ri do
    for j:=-ri to ri do
    begin
      val:=FimageMin+Fimage[0,y+j,x+i]/FimageC-bg;
      if val<0 then val:=0;
      if val>vmax then vmax:=val;
      SumVal:=SumVal+val;
      SumValX:=SumValX+val*(i);
     SumValY:=SumValY+val*(j);
    end;
  Xg:=SumValX/SumVal;
  Yg:=SumValY/SumVal;
  if ((Xg*Xg)+(Yg*Yg))>0.3 then result:=true {0.3 is experimental factor. Double star, too much unbalance between bright spot and centre of gravity}
    else
    result:=false;
  except
    on E: Exception do begin
        result:=true;
    end;
  end;
end;{double star detection}

function TFits.value_subpixel(x1,y1:double):double;
{calculate image pixel value on subpixel level}
// see: https://www.ap-i.net/mantis/file_download.php?file_id=817&type=bug
var
  x_trunc,y_trunc: integer;
  x_frac,y_frac : double;
begin
  try
  result:=0;
  x_trunc:=trunc(x1);
  y_trunc:=trunc(y1);
  if (x_trunc<=0) or (x_trunc>=(Fwidth-2)) or (y_trunc<=0) or (y_trunc>=(Fheight-2)) then exit;
  x_frac :=frac(x1);
  y_frac :=frac(y1);
  result:= Fimage[0,y_trunc ,x_trunc ] * (1-x_frac)*(1-y_frac);{pixel left top, 1}
  result:=result + Fimage[0,y_trunc ,x_trunc+1] * ( x_frac)*(1-y_frac);{pixel right top, 2}
  result:=result + Fimage[0,y_trunc+1,x_trunc ] * (1-x_frac)*( y_frac);{pixel left bottom, 3}
  result:=result + Fimage[0,y_trunc+1,x_trunc+1] * ( x_frac)*( y_frac);{pixel right bottom, 4}
  except
    on E: Exception do begin
        result:=0;
    end;
  end;
end;

procedure TFits.FindBrightestPixel(x,y,s,starwindow2: integer; out xc,yc:integer; out vmax: double; accept_double: boolean=true);
// brightest 3x3 pixels in area s*s centered on x,y
var i,j,rs,xm,ym: integer;
    bg,bg_average,bg_standard_deviation: double;
    val :double;
begin
 rs:= s div 2;
 if (x-rs)<3 then x:=rs+3;
 if (x+rs)>(Fwidth-3) then x:=Fwidth-rs-3;
 if (y-rs)<3 then y:=rs+3;
 if (y+rs)>(Fheight-3) then y:=Fheight-rs-3;

 vmax:=0;
 xm:=0;
 ym:=0;

 try

   // average background
  bg_average:=0;
  for i:=-rs+1 to rs do {calculate average background at the square boundaries of region of interest}
  begin
    bg_average:=bg_average+Fimage[0,y+rs,x+i];{top line, left to right}
    bg_average:=bg_average+Fimage[0,y+i,x+rs];{right line, top to bottom}
    bg_average:=bg_average+Fimage[0,y-rs,x-i];{bottom line, right to left}
    bg_average:=bg_average+Fimage[0,y-i,x-rs];{right line, bottom to top}
  end;
  bg_average:=bg_average/(8*rs);

  bg_standard_deviation:=0;
  for i:=-rs+1 to rs do {calculate standard deviation background at the square boundaries of region of interest}
  begin
    bg_standard_deviation:=bg_standard_deviation+sqr(bg_average-Fimage[0,y+rs,x+i]);{top line, left to right}
    bg_standard_deviation:=bg_standard_deviation+sqr(bg_average-Fimage[0,y+i,x+rs]);{right line, top to bottom}
    bg_standard_deviation:=bg_standard_deviation+sqr(bg_average-Fimage[0,y-rs,x-i]);{bottom line, right to left}
    bg_standard_deviation:=bg_standard_deviation+sqr(bg_average-Fimage[0,y-i,x-rs]);{left line, bottom to top}
  end;
  bg_standard_deviation:=sqrt(0.0001+bg_standard_deviation/(8*rs))/FimageC;

  bg:=FimageMin+bg_average/FimageC;

 // try with double star exclusion
 for i:=-rs to rs do
   for j:=-rs to rs do begin
     val:=(Fimage[0,y+j-1 ,x+i-1]+Fimage[0,y+j-1 ,x+i]+Fimage[0,y+j-1 ,x+i+1]+
           Fimage[0,y+j ,x+i-1]+Fimage[0,y+j ,x+i]+Fimage[0,y+j ,x+i+1]+
           Fimage[0,y+j+1 ,x+i-1]+Fimage[0,y+j+1 ,x+i]+Fimage[0,y+j+1 ,x+i+1])/9;

     Val:=FimageMin+Val/FimageC-bg;
     // huge performance improvement by checking only the pixels above the noise
     if (val>((5*bg_standard_deviation))) and (Val>vmax) then
     begin
       if double_star(starwindow2, x+i,y+j)=false then
       begin
         vmax:=Val;
         xm:=i;
         ym:=j;
       end;
     end;
 end;

 if accept_double then begin
 // if we not find anything repeat with only max value
 if vmax=0 then
   for i:=-rs to rs do
     for j:=-rs to rs do begin
       val:=(Fimage[0,y+j-1 ,x+i-1]+Fimage[0,y+j-1 ,x+i]+Fimage[0,y+j-1 ,x+i+1]+
             Fimage[0,y+j ,x+i-1]+Fimage[0,y+j ,x+i]+Fimage[0,y+j ,x+i+1]+
             Fimage[0,y+j+1 ,x+i-1]+Fimage[0,y+j+1 ,x+i]+Fimage[0,y+j+1 ,x+i+1])/9;

       Val:=FimageMin+Val/FimageC;
       if Val>vmax then
       begin
         vmax:=Val;
         xm:=i;
         ym:=j;
       end;
   end;
 end;

 xc:=x+xm;
 yc:=y+ym;

 except
   on E: Exception do begin
       vmax:=0;
   end;
 end;

end;


procedure TFits.FindStarPos(x,y,s: integer; out xc,yc,ri:integer; out vmax,bg,bg_standard_deviation: double);
// center of gravity in area s*s centered on x,y
const
    max_ri=100;
var i,j,rs: integer;
    SumVal,SumValX,SumValY: double;
    val,xg,yg:double;
    distance :integer;
    bg_average : double;
    distance_histogram : array [0..max_ri] of integer;
    HistStart: boolean;
begin

  vmax:=0;
  bg:=0;
  rs:=s div 2;
  if (x-s)<1 then x:=s+1;
  if (x+s)>(Fwidth-1) then x:=Fwidth-s-1;
  if (y-s)<1 then y:=s+1;
  if (y+s)>(Fheight-1) then y:=Fheight-s-1;

  try

  // average background
  bg_average:=0;
  for i:=-rs+1 to rs do {calculate average background at the square boundaries of region of interest}
  begin
    bg_average:=bg_average+Fimage[0,y+rs,x+i];{top line, left to right}
    bg_average:=bg_average+Fimage[0,y+i,x+rs];{right line, top to bottom}
    bg_average:=bg_average+Fimage[0,y-rs,x-i];{bottom line, right to left}
    bg_average:=bg_average+Fimage[0,y-i,x-rs];{right line, bottom to top}
  end;
  bg_average:=bg_average/(8*rs);

  bg_standard_deviation:=0;
  for i:=-rs+1 to rs do {calculate standard deviation background at the square boundaries of region of interest}
  begin
    bg_standard_deviation:=bg_standard_deviation+sqr(bg_average-Fimage[0,y+rs,x+i]);{top line, left to right}
    bg_standard_deviation:=bg_standard_deviation+sqr(bg_average-Fimage[0,y+i,x+rs]);{right line, top to bottom}
    bg_standard_deviation:=bg_standard_deviation+sqr(bg_average-Fimage[0,y-rs,x-i]);{bottom line, right to left}
    bg_standard_deviation:=bg_standard_deviation+sqr(bg_average-Fimage[0,y-i,x-rs]);{left line, bottom to top}
  end;
  bg_standard_deviation:=sqrt(0.0001+bg_standard_deviation/(8*rs))/FimageC;

  bg:=FimageMin+bg_average/FimageC;

  // Get center of gravity whithin star detection box
  SumVal:=0;
  SumValX:=0;
  SumValY:=0;
  vmax:=0;
  for i:=-rs to rs do
   for j:=-rs to rs do begin
     val:=FimageMin+Fimage[0,y+j,x+i]/FimageC-bg;
     if val>((3*bg_standard_deviation)) then  {>3 * sd should be signal }
     begin
       if val>vmax then vmax:=val;
       SumVal:=SumVal+val;
       SumValX:=SumValX+val*(i);
       SumValY:=SumValY+val*(j);
     end;
   end;

  if sumval=0 then
  begin
    ri:=3;
    exit;
  end;

  Xg:=SumValX/SumVal;
  Yg:=SumValY/SumVal;
  xc:=round(x+Xg);
  yc:=round(y+Yg);

 // Get diameter of signal shape above the noise level. Find maximum distance of pixel with signal from the center of gravity. This works for donut shapes.

 for i:=0 to max_ri do distance_histogram[i]:=0;{clear histogram of pixel distances}

 for i:=-rs to rs do begin
   for j:=-rs to rs do begin
     val:=FimageMin+Fimage[0,yc+j,xc+i]/FimageC-bg;
     if val>((3*bg_standard_deviation)) then {>3 * sd should be signal }
     begin
       distance:=round((sqrt(1+ i*i + j*j )));{distance from gravity center }
       if distance<=max_ri then distance_histogram[distance]:=distance_histogram[distance]+1;{build distance histogram}
     end;
   end;
  end;

 ri:=0;
 HistStart:=false;
 repeat
    inc(ri);
    if distance_histogram[ri]>0 then {continue until we found a value>0, center of reflector ring can be black}
       HistStart:=true;
 until ((ri>=max_ri) or (HistStart and (distance_histogram[ri]=0)));{find a distance where there is no pixel illuminated, so the border of the star image of interest}

 inc(ri,2);

 if ri=0 then ri:=rs;
 if ri<3 then ri:=3;

 except
   on E: Exception do begin
       vmax:=0;
   end;
 end;
end;

procedure TFits.GetHFD2(x,y,s: integer; out xc,yc,bg,bg_standard_deviation,hfd,star_fwhm,valmax,snr,flux: double; strict_saturation: boolean=true);
// x,y, s, test location x,y and box size s x s
// xc,yc, center of gravity
// bg, background value
// bf_standard_deviation, standard deviation of background
// hfd, Half Flux Diameter of star disk
// star_fwhm, Full Width Half Maximum of star disk
// valmax, maximum value of brightest pixel in final test box.
// SNR, signal noise ratio
// flux, the total star signal
// fluxsnr, the signal noise ratio on the total flux
const
    max_ri=100;
var i,j,rs,distance,counter,ri, distance_top_value, illuminated_pixels, saturated_counter, max_saturated: integer;
    valsaturation:Int64;
    SumVal,SumValX,SumValY,SumvalR,val,xg,yg,bg_average, pixel_counter,r, val_00,val_01,val_10,val_11,af,
    faintA,faintB, brightA,brightB,faintest,brightest : double;
    distance_histogram  : array [0..max_ri] of integer;
    HistStart,asymmetry : boolean;
begin
  valmax:=0;
  bg:=0;
  snr:=0;
  valmax:=0;
  hfd:=-1;
  star_fwhm:=-1;
  flux:=-1;

  if strict_saturation then
     max_saturated:=0
  else
     max_saturated:=5;

  rs:=s div 2;
  if rs>max_ri then rs:=max_ri; {protection against run time error}

  if (x-s)<1+4 then x:=s+1+4;
  if (x+s)>(Fwidth-1-4) then x:=Fwidth-s-1-4;
  if (y-s)<1+4 then y:=s+1+4;
  if (y+s)>(Fheight-1-4) then y:=Fheight-s-1-4;

  try
  // average background
  counter:=0;
  bg_average:=0;
  for i:=-rs-4 to rs+4 do {calculate mean at square boundaries of detection box}
  for j:=-rs-4 to rs+4 do
  begin
    if ( (abs(i)>rs) and (abs(j)>rs) ) then {measure only outside the box}
    begin
      bg_average:=bg_average+Fimage[0,y+i,x+j];
      inc(counter)
    end;
  end;
  bg_average:=bg_average/counter; {mean value background}
  bg:=bg_average;

  counter:=0;
  bg_standard_deviation:=0;
  for i:=-rs-4 to rs+4 do {calculate standard deviation background at the square boundaries of detection box}
    for j:=-rs-4 to rs+4 do
    begin
      if ( (abs(i)>rs) and (abs(j)>rs) ) then {measure only outside the box}
      begin
          bg_standard_deviation:=bg_standard_deviation+sqr(bg_average-Fimage[0,y+i,x+j]);
          inc(counter)
      end;
  end;
  bg_standard_deviation:=sqrt(0.0001+bg_standard_deviation/(counter)); {standard deviation in background}

  bg:=bg_average;

  repeat {## reduce box size till symmetry to remove stars}
    // Get center of gravity whithin star detection box and count signal pixels
    SumVal:=0;
    SumValX:=0;
    SumValY:=0;
    valmax:=0;
    saturated_counter:=0;
    if FFitsInfo.floatingpoint then
      valsaturation:=round(FimageC*(FimageMax-FimageMin)-bg)
    else
      valsaturation:=round(FimageC*(MaxADU-1-FimageMin)-bg);
    for i:=-rs to rs do
    for j:=-rs to rs do
    begin
      val:=Fimage[0,y+j,x+i]-bg;
      if val>(3.5)*bg_standard_deviation then {just above noise level. }
      begin
        if val>=valsaturation then inc(saturated_counter);
        if val>valmax then valmax:=val;
        SumVal:=SumVal+val;
        SumValX:=SumValX+val*(i);
        SumValY:=SumValY+val*(j);
      end;
    end;
    if sumval<=15*bg_standard_deviation then exit; {no star found, too noisy}
    Xg:=SumValX/SumVal;
    Yg:=SumValY/SumVal;
    xc:=(x+Xg);
    yc:=(y+Yg);
   {center of star gravity found}

    if ((xc-rs<=1) or (xc+rs>=Fwidth-2) or (yc-rs<=1) or (yc+rs>=Fheight-2) ) then begin exit;end;{prevent runtime errors near sides of images}

   // Check for asymmetry. Are we testing a group of stars or a defocused star?
    val_00:=0;val_01:=0;val_10:=0;val_11:=0;

    for i:=-rs to 0 do begin
      for j:=-rs to 0 do begin
        val_00:=val_00+ value_subpixel(xc+i,yc+j)-bg; {value top left}
        val_01:=val_01+ value_subpixel(xc+i,yc-j)-bg; {value bottom left}
        val_10:=val_10+ value_subpixel(xc-i,yc+j)-bg; {value top right}
        val_11:=val_11+ value_subpixel(xc-i,yc-j)-bg; {value bottom right}
      end;
    end;
    af:=0.30; {## asymmetry factor. 1=is allow only prefect symmetrical, 0.000001=off}
              {0.30 make focusing to work with bad seeing}

    {check for asymmetry of detected star using the four quadrants}
    if val_00<val_01  then begin faintA:=val_00; brightA:=val_01; end else begin faintA:=val_01; brightA:=val_00; end;
    if val_10<val_11  then begin faintB:=val_10; brightB:=val_11; end else begin faintB:=val_11; brightB:=val_10; end;
    if faintA<faintB  then faintest:=faintA else faintest:=faintB;{find faintest quadrant}
    if brightA>brightB  then brightest:=brightA else brightest:=brightB;{find brightest quadrant}
    asymmetry:=(brightest*af>=faintest); {if true then detected star has asymmetry, ovals/galaxies or double stars will not be accepted}

    if asymmetry then dec(rs,2); {try a smaller window to exclude nearby stars}
    if rs<4 then exit; {try to reduce box up to rs=4 equals 8x8 box else exit}
  until asymmetry=false; {loop and reduce box size until asymmetry is gone or exit if box is too small}

  // Get diameter of star above the noise level.
  for i:=0 to rs do distance_histogram[i]:=0;{clear histogram of pixel distances}

  for i:=-rs to rs do begin
    for j:=-rs to rs do begin
      distance:=round((sqrt(i*i + j*j )));{distance from star gravity center }
      if distance<=rs then {build histogram for circel with radius rs}
      begin
        Val:=value_subpixel(xc+i,yc+j)-bg;
        if val>((3*bg_standard_deviation)) then {>3 * sd should be signal }
          distance_histogram[distance]:=distance_histogram[distance]+1;{build distance histogram}
      end;
    end;
  end;

  ri:=-1; {will start from distance 0}
  distance_top_value:=0;
  HistStart:=false;
  illuminated_pixels:=0;
  repeat
    inc(ri);
    illuminated_pixels:=illuminated_pixels+distance_histogram[ri];
    if distance_histogram[ri]>0 then HistStart:=true;{continue until we found a value>0, center of defocused star image can be black having a central obstruction in the telescope}
    if distance_top_value<distance_histogram[ri] then distance_top_value:=distance_histogram[ri]; {this should be 2*pi*ri if it is nice defocused star disk}
  until ((ri>=rs) or (HistStart and (distance_histogram[ri]<=0.1*distance_top_value {drop-off detection})));{find a distance where there is no pixel illuminated, so the border of the star image of interest}

  if ri>=rs then {star is equal or larger then box, abort} exit; {hfd:=-1}
  if (ri>2)and(illuminated_pixels<0.35*sqr(ri+ri-2)){35% surface} then {not a star disk but stars, abort} exit; {hfd:=-1}
  if ri<3 then ri:=3; {Minimum 6+1 x 6+1 pixel box}

  // Get HFD using the aproximation routine assuming that HFD line divides the star in equal portions of gravity:
  SumVal:=0;
  SumValR:=0;
  pixel_counter:=0;

  for i:=-ri to ri do {Make steps of one pixel}
    for j:=-ri to ri do
    begin
      Val:=value_subpixel(xc+i,yc+j)-bg;{The calculated center of gravity is a floating point position and can be anyware, so calculate pixel values on sub-pixel level}
      r:=sqrt(i*i+j*j);{Distance from star gravity center}
      SumVal:=SumVal+Val;{Sumval will be star total flux value}
      SumValR:=SumValR+Val*r; {Method Kazuhisa Miyashita, see notes of HFD calculation method}
      if val>=valmax*0.5 then pixel_counter:=pixel_counter+1;{How many pixels are above half maximum for FWHM}
    end;
  if (not Undersampled) and (pixel_counter<=1) then exit; // reject hot pixel in noisy environment
  if Sumval<0.00001 then Sumval:=0.00001;{prevent divide by zero}
  hfd:=2*SumValR/SumVal;
  hfd:=max(0.7,hfd); // minimum value for a star size of 1 pixel
  star_fwhm:=2*sqrt(pixel_counter/pi);{The surface is calculated by counting pixels above half max. The diameter of that surface called FWHM is then 2*sqrt(surface/pi) }
  if (SumVal>0.00001)and(saturated_counter<=max_saturated) then begin
    flux:=Sumval/FimageC;
    snr:=flux/sqrt(flux +sqr(ri)*pi*sqr(bg_standard_deviation/FimageC)); {For both bright stars (shot-noise limited) or skybackground limited situations
                                                                     snr:=signal/sqrt(signal + r*r*pi* SKYsignal) equals snr:=flux/sqrt(flux + r*r*pi* sd^2).}
  end else begin
    flux:=-1;
    snr:=0;
  end;


{==========Notes on HFD calculation method=================
  https://en.wikipedia.org/wiki/Half_flux_diameter
  http://www005.upp.so-net.ne.jp/k_miyash/occ02/halffluxdiameter/halffluxdiameter_en.html       by Kazuhisa Miyashita. No sub-pixel calculation
  https://www.lost-infinity.com/night-sky-image-processing-part-6-measuring-the-half-flux-diameter-hfd-of-a-star-a-simple-c-implementation/
  http://www.ccdware.com/Files/ITS%20Paper.pdf     See page 10, HFD Measurement Algorithm

  HFD, Half Flux Diameter is defined as: The diameter of circle where total flux value of pixels inside is equal to the outside pixel's.
  HFR, half flux radius:=0.5*HFD
  The pixel_flux:=pixel_value - background.

  The approximation routine assumes that the HFD line divides the star in equal portions of gravity:
      sum(pixel_flux * (distance_from_the_centroid - HFR))=0
  This can be rewritten as
     sum(pixel_flux * distance_from_the_centroid) - sum(pixel_values * (HFR))=0
     or
     HFR:=sum(pixel_flux * distance_from_the_centroid))/sum(pixel_flux)
     HFD:=2*HFR

  This is not an exact method but a very efficient routine. Numerical checking with an a highly oversampled artificial Gaussian shaped star indicates the following:

  Perfect two dimensional Gaussian shape with σ=1:   Numerical HFD=2.3548*σ                     Approximation 2.5066, an offset of +6.4%
  Homogeneous disk of a single value  :              Numerical HFD:=disk_diameter/sqrt(2)       Approximation disk_diameter/1.5, an offset of -6.1%

  The approximation routine is robust and efficient.

  Since the number of pixels illuminated is small and the calculated center of star gravity is not at the center of an pixel, above summation should be calculated on sub-pixel level (as used here)
  or the image should be re-sampled to a higher resolution.

  A sufficient signal to noise is required to have valid HFD value due to background noise.

  Note that for perfect Gaussian shape both the HFD and FWHM are at the same 2.3548 σ.
  }


   {=============Notes on FWHM:=====================
      1)	Determine the background level by the averaging the boarder pixels.
      2)	Calculate the standard deviation of the background.

          Signal is anything 3 * standard deviation above background

      3)	Determine the maximum signal level of region of interest.
      4)	Count pixels which are equal or above half maximum level.
      5)	Use the pixel count as area and calculate the diameter of that area  as diameter:=2 *sqrt(count/pi).}


  except
    on E: Exception do begin
      hfd:=-1;
      star_fwhm:=-1;
    end;
  end;
end;{gethfd2}

procedure TFits.ClearStarList;
begin
  SetLength(FStarList,0);
end;

procedure TFits.GetStarList(rx,ry,s: integer);
var
 i,j,n,nhfd: integer;
 overlap: integer;
 img_temp: Timai8;
 working, timingout: boolean;
 timelimit: TDateTime;
 thread: array[0..15] of TGetStarList;
 tc,timeout: integer;
begin
  overlap:=round(s/3); // large overlap to have more chance to measure a big dot as a single piece
  s:=round(2*s/3);     // keep original window size after adding overlap
  SetLength(img_temp,1,FWidth,FHeight); {array to check for duplicate}
  for j:=0 to Fheight-1 do
     for i:=0 to FWidth-1 do
        img_temp[0,i,j]:=0;  {mark as not surveyed}
  thread[0]:=nil;
  // number of thread
   tc := max(1,min(16, MaxThreadCount)); // based on number of core
   tc := max(1,min(tc,Fheight div (100+2*s))); // do not split the image too much
  // start thread
  for i := 0 to tc - 1 do
  begin
    thread[i] := TGetStarList.Create(true);
    thread[i].fits := self;
    thread[i].num := tc;
    thread[i].id := i;
    thread[i].rx := rx;
    thread[i].ry := ry;
    thread[i].overlap := overlap;
    thread[i].s := s;
    thread[i].img_temp := img_temp;
    thread[i].Start;
  end;
  // wait complete
  timeout:=60;
  timelimit := now + timeout / secperday;
  repeat
    sleep(100);
    working := False;
    for i := 0 to tc - 1 do
      working := working or thread[i].working;
    timingout := (now > timelimit);
  until (not working) or timingout;
  SetLength(img_temp,0,0,0);
  // copy result
  nhfd:=0;
  for i:=0 to tc - 1 do
    nhfd:=nhfd+Length(thread[i].StarList);
  SetLength(FStarList,nhfd);
  n:=0;
  for i:=0 to tc - 1 do begin
    for j:=0 to Length(thread[i].StarList)-1 do begin
       FStarList[n]:=thread[i].StarList[j];
       inc(n);
    end;
  end;
  // cleanup
  for i:=0 to tc - 1 do SetLength(thread[i].StarList,0);
  for i := 0 to tc - 1 do thread[i].Free;
end;

procedure TFits.MeasureStarList(s: integer; list: TArrayDouble2);
var
 fitsX,fitsY,nhfd,i: integer;
 hfd1,star_fwhm,vmax,bg,bgdev,xc,yc,snr,flux: double;
begin

nhfd:=0;{set counters at zero}
SetLength(FStarList,1000);{allocate initial size}

for i:=0 to Length(list)-1 do
 begin
   fitsX:=round(list[i,1]);
   fitsY:=round(list[i,2]);
   hfd1:=-1;
   star_fwhm:=-1;

   GetHFD2(fitsX,fitsY,s,xc,yc,bg,bgdev,hfd1,star_fwhm,vmax,snr,flux,false);

   // normalize value
   vmax:=vmax/FimageC; // include bg subtraction
   bg:=FimageMin+bg/FimageC;


   {check valid hfd, snr}
   if (((hfd1>0)and(Undersampled or (hfd1>0.8))) and (hfd1<99) and (snr>3)) then
    begin
       inc(nhfd);
       if nhfd>=Length(FStarList) then
          SetLength(FStarList,nhfd+1000);  {get more space to store values}
       FStarList[nhfd-1].x:=xc;
       FStarList[nhfd-1].y:=yc;
       FStarList[nhfd-1].hfd:=hfd1;
       FStarList[nhfd-1].fwhm:=star_fwhm;
       FStarList[nhfd-1].snr:=snr;
       FStarList[nhfd-1].vmax:=vmax;
       FStarList[nhfd-1].bg:=bg;
    end;
 end;
 SetLength(FStarList,nhfd);  {set length to new number of elements}
end;

function TFits.SameFormat(f:TFits): boolean;
begin
 result := (f<>nil) and f.FFitsInfo.valid and
           (f.FFitsInfo.bitpix = FFitsInfo.bitpix)  and
           (f.FFitsInfo.naxis  = FFitsInfo.naxis )  and
           (f.FFitsInfo.naxis1 = FFitsInfo.naxis1 ) and
           (f.FFitsInfo.naxis2 = FFitsInfo.naxis2 ) and
           (f.FFitsInfo.naxis3 = FFitsInfo.naxis3 ) and
           (f.FFitsInfo.bzero  = FFitsInfo.bzero )  and
           (f.FFitsInfo.bscale = FFitsInfo.bscale );
end;

procedure TFits.Bitpix8to16;
var i,j,k,ii: integer;
    x: smallint;
begin
 if FFitsInfo.bitpix = 8 then begin
   setlength(imai16,n_axis,Fheight,Fwidth);
   for k:=cur_axis-1 to cur_axis+n_axis-2 do begin
     for i:=0 to FFitsInfo.naxis2-1 do begin
      ii:=FFitsInfo.naxis2-1-i;
      for j := 0 to FFitsInfo.naxis1-1 do begin
        x:=-32767+imai8[k,ii,j];
        imai16[k,ii,j]:=x;
      end;
     end;
   end;
 end;
 FFitsInfo.bitpix:=16;
 FFitsInfo.bscale:=1;
 FFitsInfo.bzero:=32768;
 i:=FHeader.Indexof('BITPIX');
 if i>=0 then FHeader.Delete(i);
 FHeader.Insert(i,'BITPIX',16,'');
 i:=FHeader.Indexof('BSCALE');
 if i>=0 then FHeader.Delete(i);
 FHeader.Insert(i,'BSCALE',1,'');
 i:=FHeader.Indexof('BZERO');
 if i>=0 then FHeader.Delete(i);
 FHeader.Insert(i,'BZERO',32768,'');
 setlength(imai8,0,0,0);
 WriteFitsImage;
end;

procedure TFits.Math(operand: TFits; MathOperator:TMathOperator; new: boolean=false);
var i,j,k,ii: integer;
    x,y,dmin,dmax,minoffset : double;
    ni,sum,sum2 : extended;
    m: TMemoryStream;
begin
 if new or (Fheight=0)or(Fwidth=0)then begin  // first frame, just store the operand
   m:=operand.Stream;
   SetStream(m);
   LoadStream;
   m.free;
 end
 else begin  // do operation

   if not FImageValid then LoadStream;
   dmin:=1.0E100;
    dmax:=-1.0E100;
    sum:=0; sum2:=0; ni:=0;
    minoffset:=operand.FFitsInfo.dmin-FFitsInfo.dmin;
    for k:=cur_axis-1 to cur_axis+n_axis-2 do begin
      for i:=0 to FFitsInfo.naxis2-1 do begin
       ii:=FFitsInfo.naxis2-1-i;
       for j := 0 to FFitsInfo.naxis1-1 do begin
         case FFitsInfo.bitpix of
          -64 : begin
                x:=FFitsInfo.bzero+FFitsInfo.bscale*imar64[k,ii,j];
                y:=operand.FFitsInfo.bzero+operand.FFitsInfo.bscale*operand.imar64[k,ii,j];
                end;
          -32 : begin
                x:=FFitsInfo.bzero+FFitsInfo.bscale*imar32[k,ii,j];
                y:=operand.FFitsInfo.bzero+operand.FFitsInfo.bscale*operand.imar32[k,ii,j];
                end;
            8 : begin
                x:=FFitsInfo.bzero+FFitsInfo.bscale*imai8[k,ii,j];
                y:=operand.FFitsInfo.bzero+operand.FFitsInfo.bscale*operand.imai8[k,ii,j];
                end;
           16 : begin
                x:=FFitsInfo.bzero+FFitsInfo.bscale*imai16[k,ii,j];
                y:=operand.FFitsInfo.bzero+operand.FFitsInfo.bscale*operand.imai16[k,ii,j];
                end;
           32 : begin
                x:=FFitsInfo.bzero+FFitsInfo.bscale*imai32[k,ii,j];
                y:=operand.FFitsInfo.bzero+operand.FFitsInfo.bscale*operand.imai32[k,ii,j];
                end;
           else begin x:=0; y:=0; end;
         end;
         case MathOperator of
           moAdd: x:=x+y;
           moSub: x:=x-y+minoffset;
           moMean: x:=(x+y)/2;
           moMult: x:=x*y;
           moDiv : x:=x/y;
         end;
         x:=(x-FFitsInfo.bzero)/FFitsInfo.bscale;
         case FFitsInfo.bitpix of
          -64 : imar64[k,ii,j] := x;
          -32 : imar32[k,ii,j] := x;
            8 : begin x:=max(min(round(x),MAXBYTE),0); imai8[k,ii,j] := round(x); end;
           16 : begin x:=max(min(round(x),maxSmallint),-maxSmallint-1);  imai16[k,ii,j] :=round(x); end;
           32 : begin x:= max(min(round(x),maxLongint),-maxLongint-1); imai32[k,ii,j] := round(x); end;
         end;
         dmin:=min(x,dmin);
         dmax:=max(x,dmax);
         sum:=sum+x;
         sum2:=sum2+x*x;
         ni:=ni+1;
       end;
      end;
    end;
    FStreamValid:=false;
    dmin:=FFitsInfo.bzero+FFitsInfo.bscale*dmin;
    dmax:=FFitsInfo.bzero+FFitsInfo.bscale*dmax;
    Fmean:=FFitsInfo.bzero+FFitsInfo.bscale*(sum/ni);
    Fsigma:=FFitsInfo.bscale*(sqrt((sum2/ni)-((sum/ni)*(sum/ni))));
    if dmin>=dmax then dmax:=dmin+1;
    FFitsInfo.dmin:=dmin;
    FFitsInfo.dmax:=dmax;
    GetImage;
 end;
end;

procedure TFits.Shift(dx,dy: double);
begin
  // for now use integer shift, next is to try with value_subpixel()
  ShiftInteger(round(dx),round(dy));
end;

procedure TFits.ShiftInteger(dx,dy: integer);
var imgshift: TFits;
    i,ii,j,k,x,y: integer;
    m: TMemoryStream;
begin
  imgshift:=TFits.Create(nil);
  imgshift.onMsg:=onMsg;
  imgshift.SetStream(FStream);
  imgshift.LoadStream;
  for k:=cur_axis-1 to cur_axis+n_axis-2 do begin
    for i:=0 to FFitsInfo.naxis2-1 do begin
     ii:=FFitsInfo.naxis2-1-i;
     for j := 0 to FFitsInfo.naxis1-1 do begin
       x:=j-dx;
       y:=ii-dy;
       if (x>0)and(x<FFitsInfo.naxis1)and(y>0)and(y<FFitsInfo.naxis2) then begin
         case FFitsInfo.bitpix of
          -64 : begin
                imgshift.imar64[k,ii,j]:=imar64[k,y,x];
                end;
          -32 : begin
                imgshift.imar32[k,ii,j]:=imar32[k,y,x];
                end;
            8 : begin
                imgshift.imai8[k,ii,j]:=imai8[k,y,x];
                end;
           16 : begin
                imgshift.imai16[k,ii,j]:=imai16[k,y,x];
                end;
           32 : begin
                imgshift.imai32[k,ii,j]:=imai32[k,y,x];
                end;
         end;
       end
       else begin
        case FFitsInfo.bitpix of
         -64 : begin
               imgshift.imar64[k,ii,j]:=-FFitsInfo.bzero;
               end;
         -32 : begin
               imgshift.imar32[k,ii,j]:=-FFitsInfo.bzero;
               end;
           8 : begin
               imgshift.imai8[k,ii,j]:=0;
               end;
          16 : begin
               imgshift.imai16[k,ii,j]:=-maxSmallint;
               end;
          32 : begin
               imgshift.imai32[k,ii,j]:=-maxLongint;
               end;
        end;
       end;
     end;
    end;
  end;
  imgshift.FStreamValid:=false;
  m:=imgshift.Stream;
  SetStream(m);
  LoadStream;
  GetImage;
  imgshift.Free;
  m.free;
end;

procedure PictureToFits(pict:TMemoryStream; ext: string; var ImgStream:TMemoryStream; flip:boolean=true;pix:double=-1;piy:double=-1;binx:integer=-1;biny:integer=-1;bayer:string='';rmult:string='';gmult:string='';bmult:string='';origin:string='';exifkey:TStringList=nil;exifvalue:TStringList=nil);
var img:TLazIntfImage;
    lRawImage: TRawImage;
    i,j,c,w,h,x,y,naxis: integer;
    ii: smallint;
    b: array[0..2880]of char;
    hdr: TFitsHeader;
    hdrmem: TMemoryStream;
    RedStream,GreenStream,BlueStream: TMemoryStream;
    htyp,hext: string;
    ReaderClass: TFPCustomImageReaderClass;
   Reader: TFPCustomImageReader;
begin
 // define raw image data
 lRawImage.Init;
 with lRawImage.Description do begin
  // Set format 48bit R16G16B16
  Format := ricfRGBA;
  Depth := 48; // used bits per pixel
  Width := 0;
  Height := 0;
  BitOrder := riboBitsInOrder;
  ByteOrder := riboLSBFirst;
  LineOrder := riloTopToBottom;
  BitsPerPixel := 48; // bits per pixel. can be greater than Depth.
  LineEnd := rileDWordBoundary;
  RedPrec := 16; // red precision. bits for red
  RedShift := 0;
  GreenPrec := 16;
  GreenShift := 16; // bitshift. Direction: from least to most significant
  BluePrec := 16;
  BlueShift:=32;
 end;
 // create resources
 lRawImage.CreateData(false);
 hdr:=TFitsHeader.Create;
 ImgStream.Clear;
 ImgStream.Position:=0;
 img:=TLazIntfImage.Create(0,0);
 ext:=uppercase(ext);
 try
   // set image data
   img.SetRawImage(lRawImage);
   // search a reader for the given fileext
   for i:=0 to ImageHandlers.Count-1 do begin
     htyp:=ImageHandlers.TypeNames[i];
     hext:=uppercase(ImageHandlers.Extensions[htyp]);
     if (pos(ext,hext)>0) then begin
       // load image from file, it use the correct reader from fileext
       ReaderClass:=ImageHandlers.ImageReader[htyp];
       Reader:=ReaderClass.Create;
       try
       pict.Position:=0;
       // load image from file, using the reader
       img.LoadFromStream(pict,Reader);
       reader.free;
       break;
       except
         // not the right reader, continue to try another
         reader.free;
       end;
     end;
   end;
   w:=img.Width;
   h:=img.Height;
   if (h=0)or(w=0) then begin
     exit;
   end;
   // detect BW or color
   naxis:=2;
   for i:=0 to (h-1)div 10 do begin
      y:=10*i;
      for j:=0 to (w-1)div 10 do begin
        x:=10*j;
        if (img.Colors[x,y].red <> img.Colors[x,y].green)or(img.Colors[x,y].red <> img.Colors[x,y].blue) then begin
           naxis:=3;
           break;
        end;
      end;
      if naxis=3 then break;
   end;
   // create fits header
   hdr.ClearHeader;
   hdr.Add('SIMPLE',true,'file does conform to FITS standard');
   hdr.Add('BITPIX',16,'number of bits per data pixel');
   hdr.Add('NAXIS',naxis,'number of data axes');
   hdr.Add('NAXIS1',w ,'length of data axis 1');
   hdr.Add('NAXIS2',h ,'length of data axis 2');
   if naxis=3 then hdr.Add('NAXIS3',3 ,'length of data axis 3');
   hdr.Add('EXTEND',true,'FITS dataset may contain extensions');
   hdr.Add('BZERO',32768,'offset data range to that of unsigned short');
   hdr.Add('BSCALE',1,'default scaling factor');
   if pix>0 then hdr.Add('PIXSIZE1',pix ,'Pixel Size 1 (microns)');
   if piy>0 then hdr.Add('PIXSIZE2',piy ,'Pixel Size 2 (microns)');
   if binx>0 then hdr.Add('XBINNING',binx ,'Binning factor in width');
   if biny>0 then hdr.Add('YBINNING',biny ,'Binning factor in height');
   if bayer<>'' then begin
     hdr.Add('XBAYROFF',0,'X offset of Bayer array');
     hdr.Add('YBAYROFF',0,'Y offset of Bayer array');
     hdr.Add('BAYERPAT',bayer,'CFA Bayer pattern');
     if rmult<>'' then hdr.Add('MULT_R',rmult,'R multiplier');
     if gmult<>'' then hdr.Add('MULT_G',gmult,'G multiplier');
     if bmult<>'' then hdr.Add('MULT_B',bmult,'B multiplier');
   end;
   hdr.Add('DATE',FormatDateTime(dateisoshort,NowUTC),'Date data written');
   hdr.Add('SWCREATE','CCDciel '+ccdciel_version+'-'+RevisionStr,'');
   if (exifkey<>nil)and(exifvalue<>nil)and(exifkey.Count>0) then begin
     for i:=0 to exifkey.Count-1 do begin
        hdr.Add('HIERARCH',StringReplace(exifkey[i],'.',' ',[rfReplaceAll])+' = '''+exifvalue[i]+'''','');
     end;
   end;
   if origin='' then
     hdr.Add('COMMENT','Converted from '+ext,'')
   else
     hdr.Add('COMMENT','Converted from camera RAW by '+origin,'');
   hdr.Add('END','','');
   hdrmem:=hdr.GetStream;
   try
     // put header in stream
     ImgStream.position:=0;
     hdrmem.Position:=0;
     ImgStream.CopyFrom(hdrmem,hdrmem.Size);
   finally
     hdrmem.Free;
   end;
   // load image
   if naxis=2 then begin
     // BW image
     for i:=0 to h-1 do begin
        if flip then y:=h-1-i
                else y:=i;
        for j:=0 to w-1 do begin
          ii:=img.Colors[j,y].red-32768;
          ii:=NtoBE(ii);
          ImgStream.Write(ii,sizeof(smallint));
        end;
     end;
   end
   else begin
     // Color image
     // put data in stream by color
     RedStream:=TMemoryStream.Create;
     GreenStream:=TMemoryStream.Create;
     BlueStream:=TMemoryStream.Create;
     try
     for i:=0 to h-1 do begin
        if flip then y:=h-1-i
                else y:=i;
        for j:=0 to w-1 do begin
          ii:=img.Colors[j,y].red-32768;
          ii:=NtoBE(ii);
          RedStream.Write(ii,sizeof(smallint));
          ii:=img.Colors[j,y].green-32768;
          ii:=NtoBE(ii);
          GreenStream.Write(ii,sizeof(smallint));
          ii:=img.Colors[j,y].blue-32768;
          ii:=NtoBE(ii);
          BlueStream.Write(ii,sizeof(smallint));
        end;
     end;
     // put the 3 color plane in image stream
     RedStream.Position:=0;
     ImgStream.CopyFrom(RedStream,RedStream.Size);
     GreenStream.Position:=0;
     ImgStream.CopyFrom(GreenStream,GreenStream.Size);
     BlueStream.Position:=0;
     ImgStream.CopyFrom(BlueStream,BlueStream.Size);
     finally
       RedStream.Free;
       GreenStream.Free;
       BlueStream.Free;
     end;
   end;
   // fill to fits buffer size
   b:='';
   c:=ImgStream.Size mod 2880;
   if c>0 then begin
     c:=2880-c;
     FillChar(b,c,0);
     ImgStream.Write(b,c);
   end;
 finally
   // Free resources
   hdr.Free;
   img.free;
 end;
end;

procedure GetExif(raw:TMemoryStream; exifkey,exifvalue:TStringList);
var cmd,fn,k,v: string;
    r: Tstringlist;
    i,j,n: integer;
begin
 if Exiv2Cmd<>'' then begin
   r:=Tstringlist.Create;
   try
   fn:=slash(TmpDir)+'exiftmp.raw';
   raw.SaveToFile(fn);
   cmd:=Exiv2Cmd+' -PEkt '+fn;
   n:=ExecProcess(cmd,r);
   if n=0 then begin
     for i:=0 to r.Count-1 do begin
       j:=pos(' ',r[i]);
       if j>0 then begin
         k:=trim(copy(r[i],1,j));
         v:=trim(copy(r[i],j,999));
         if (length(k+v)<65)and(v<>'(Binary value suppressed)') then begin
           exifkey.Add(k);
           exifvalue.Add(v);
         end;
       end;
     end;
   end;
   finally
     r.free;
   end;
 end;
end;

procedure RawToFits(raw:TMemoryStream; var ImgStream:TMemoryStream; out rmsg:string; pix:double=-1;piy:double=-1;binx:integer=-1;biny:integer=-1);
var i,j,n,x,c: integer;
    xs,ys,xmax,ymax: integer;
    rawinfo:TRawInfo;
    rawinfo2:TRawInfo2;
    buf: array of char;
    msg: array[0..1024] of char;
    pmsg: PChar;
    xx: SmallInt;
    hdr: TFitsHeader;
    hdrmem: TMemoryStream;
    b: array[0..2880]of char;
    rawf,tiff,cmdi,cmdu,txt,bayerpattern: string;
    outr: TStringList;
    rmult,gmult,bmult: string;
    infook: boolean;
    exifkey,exifvalue: TStringList;
begin
rmsg:='';
try
exifkey:=TStringList.Create;
exifvalue:=TStringList.Create;
if WantExif then begin
  GetExif(raw,exifkey,exifvalue);
end;
if libraw<>0 then begin  // Use libraw directly
  try
  {$ifdef debug_raw}writeln(FormatDateTime(dateiso,Now)+blank+'Copy raw buffer');{$endif}
  i:=raw.Size;
  SetLength(buf,i+1);
  raw.Position:=0;
  raw.Read(buf[0],i);
  except
    rmsg:='Error loading file';
    exit;
  end;
  try
  {$ifdef debug_raw}writeln(FormatDateTime(dateiso,Now)+blank+'libraw LoadRaw');{$endif}
  n:=LoadRaw(@buf[0],i);
  SetLength(buf,0);
  if n<>0 then begin
    pmsg:=@msg;
    GetRawErrorMsg(n,pmsg);
    rmsg:=msg;
    exit;
  end;
  {$ifdef debug_raw}writeln(FormatDateTime(dateiso,Now)+blank+'GetRawInfo');{$endif}
  rawinfo.bitmap:=nil;
  n:=GetRawInfo(rawinfo);
  if (n<>0) or (rawinfo.bitmap=nil) then begin
   rmsg:='GetRawInfo error';
   exit;
  end;
  rawinfo2.version:=3;
  infook:=false;
  if @GetRawInfo2<>nil then begin
     n:=GetRawInfo2(rawinfo2);
     infook:=(n=0);
  end;
  xs:=rawinfo.leftmargin;
  ys:=rawinfo.topmargin;
  xmax:=xs+rawinfo.imgwidth;
  ymax:=ys+rawinfo.imgheight;
  if (xmax>rawinfo.rawwidth)or(ymax>rawinfo.rawheight) then begin
    rmsg:='Inconsistant image size: leftmargin='+inttostr(rawinfo.leftmargin)+'topmargin='+inttostr(rawinfo.topmargin)+
          'imgwidth='+inttostr(rawinfo.imgwidth)+'imgheight='+inttostr(rawinfo.imgheight)+
          'rawwidth='+inttostr(rawinfo.rawwidth)+'rawheight='+inttostr(rawinfo.rawheight);
    exit;
  end;
  {$ifdef debug_raw}writeln(FormatDateTime(dateiso,Now)+blank+'Create FITS header');{$endif}
  hdr:=TFitsHeader.Create;
  hdr.ClearHeader;
  hdr.Add('SIMPLE',true,'file does conform to FITS standard');
  hdr.Add('BITPIX',16,'number of bits per data pixel');
  hdr.Add('NAXIS',2,'number of data axes');
  hdr.Add('NAXIS1',rawinfo.imgwidth ,'length of data axis 1');
  hdr.Add('NAXIS2',rawinfo.imgheight ,'length of data axis 2');
  hdr.Add('EXTEND',true,'FITS dataset may contain extensions');
  hdr.Add('BZERO',32768,'offset data range to that of unsigned short');
  hdr.Add('BSCALE',1,'default scaling factor');
  if pix>0 then hdr.Add('PIXSIZE1',pix ,'Pixel Size 1 (microns)');
  if piy>0 then hdr.Add('PIXSIZE2',piy ,'Pixel Size 2 (microns)');
  if binx>0 then hdr.Add('XBINNING',binx ,'Binning factor in width');
  if biny>0 then hdr.Add('YBINNING',biny ,'Binning factor in height');
  if infook and (rawinfo2.version>1) then begin
    txt:=copy(trim(rawinfo2.camera),1,40);
    if txt<>'' then hdr.Add('CAMERA', txt ,'Camera model');
  end;
  if infook and (rawinfo2.version>=3) and (rawinfo2.temperature>-273) then hdr.Add('CCD-TEMP',rawinfo2.temperature ,'CCD temperature (Celsius)');
  if infook and (rawinfo2.version>1) and (rawinfo2.focal_len>0) then hdr.Add('FOCALLEN',rawinfo2.focal_len ,'Camera focal length');
  if infook and (rawinfo2.version>1) and (rawinfo2.aperture>0) then hdr.Add('F_STOP',round(10*rawinfo2.aperture)/10 ,'Camera F-stop');
  if infook and (rawinfo2.version>1) and (rawinfo2.isospeed>0) then hdr.Add('ISOSPEED',rawinfo2.isospeed ,'Camera ISO speed');
  if infook and (rawinfo2.version>1) and (rawinfo2.shutter>0) then hdr.Add('SHUTTER',rawinfo2.shutter ,'Camera shutter');
  if infook and (rawinfo2.version>1) and (rawinfo2.timestamp>0) then hdr.Add('DATE-OBS',FormatDateTime(dateisoshort,UnixToDateTime(rawinfo2.timestamp)) ,'Camera timestamp');
  hdr.Add('XBAYROFF',0,'X offset of Bayer array');
  hdr.Add('YBAYROFF',0,'Y offset of Bayer array');
  hdr.Add('BAYERPAT',rawinfo.bayerpattern,'CFA Bayer pattern');
  if infook and (rawinfo2.version>1) and (rawinfo2.colors=3) then begin
    hdr.Add('MULT_R',rawinfo2.rmult,'R multiplier');
    hdr.Add('MULT_G',rawinfo2.gmult,'G multiplier');
    hdr.Add('MULT_B',rawinfo2.bmult,'B multiplier');
  end;
  hdr.Add('DATE',FormatDateTime(dateisoshort,NowUTC),'Date data written');
  hdr.Add('SWCREATE','CCDciel '+ccdciel_version+'-'+RevisionStr,'');
  if exifkey.Count>0 then begin
    for i:=0 to exifkey.Count-1 do begin
       hdr.Add('HIERARCH',StringReplace(exifkey[i],'.',' ',[rfReplaceAll])+' = '''+exifvalue[i]+'''','');
    end;
  end;
  hdr.Add('COMMENT','Converted from camera RAW by libraw','');
  hdr.Add('END','','');
  hdrmem:=hdr.GetStream;
  try
    // put header in stream
    ImgStream.position:=0;
    hdrmem.Position:=0;
    ImgStream.CopyFrom(hdrmem,hdrmem.Size);
  finally
    hdrmem.Free;
  end;
  hdr.Free;
  {$ifdef debug_raw}writeln(FormatDateTime(dateiso,Now)+blank+'Copy data to FITS');{$endif}
  for i:=ys to ymax-1 do begin
    for j:=xs to xmax-1 do begin
      {$RANGECHECKS OFF} x:=TRawBitmap(rawinfo.bitmap)[i*(rawinfo.rawwidth)+j];
      if x>0 then
         xx:=x-32768
      else
         xx:=-32768;
      xx:=NtoBE(xx);
      ImgStream.Write(xx,sizeof(smallint));
    end;
  end;
  b:='';
  c:=ImgStream.Size mod 2880;
  if c>0 then begin
    c:=2880-c;
    FillChar(b,c,0);
    ImgStream.Write(b,c);
  end;
  CloseRaw();
  {$ifdef debug_raw}writeln(FormatDateTime(dateiso,Now)+blank+'RawToFITS end');{$endif}
  except
    rmsg:='Error converting raw file';
  end;
end
else if RawUnpCmd<>'' then begin  // try libraw tools
 try
 rawf:=slash(TmpDir)+'tmp.raw';
 tiff:=slash(TmpDir)+'tmp.raw.tiff';
 DeleteFile(tiff);
 cmdi:=RawIdCmd+' -v '+rawf;
 cmdu:=RawUnpCmd+' -T '+rawf;
 raw.Position:=0;
 raw.SaveToFile(rawf);
 raw.clear;
 outr:=TStringList.Create;
 if ExecProcess(cmdi,outr)<>0 then begin
   exit;
 end;
 for i:=0 to outr.Count-1 do begin
    if copy(outr[i],1,15)='Filter pattern:' then begin
      txt:=outr[i];
      Delete(txt,1,16);
      txt:=trim(txt);
      bayerpattern:=copy(txt,1,4); // Filter pattern: RGGBRGGBRGGBRGGB
    end;
    if copy(outr[i],1,24)='Derived D65 multipliers:' then begin
      txt:=outr[i];
      Delete(txt,1,25);
      txt:=trim(txt);
      rmult:=words(txt,' ',1,1);
      gmult:=words(txt,' ',2,1);
      bmult:=words(txt,' ',3,1);
    end;
 end;
 if ExecProcess(cmdu,outr)<>0 then begin
   exit;
 end;
 raw.LoadFromFile(tiff);
 PictureToFits(raw,'tiff',ImgStream,false,pix,piy,binx,biny,bayerpattern,rmult,gmult,bmult,'LibRaw tools',exifkey,exifvalue);
 outr.Free;
 except
   rmsg:='Error converting raw file';
 end; end
else if DcrawCmd<>'' then begin  // try dcraw command line
  try
  rawf:=slash(TmpDir)+'tmp.raw';
  tiff:=slash(TmpDir)+'tmp.tiff';
  DeleteFile(tiff);
  cmdi:=DcrawCmd+' -i -t 0 -v '+rawf;
  cmdu:=DcrawCmd+' -D -4 -t 0 -T '+rawf;
  raw.Position:=0;
  raw.SaveToFile(rawf);
  raw.clear;
  outr:=TStringList.Create;
  if ExecProcess(cmdi,outr)<>0 then begin
    exit;
  end;
  for i:=0 to outr.Count-1 do begin
     if copy(outr[i],1,15)='Filter pattern:' then begin
       txt:=outr[i];
       Delete(txt,1,16);
       txt:=trim(txt);
       bayerpattern:=copy(txt,1,2)+copy(txt,4,2); // Filter pattern: RG/GB
       break;
     end;
  end;
  if ExecProcess(cmdu,outr)<>0 then begin
    exit;
  end;
  raw.LoadFromFile(tiff);
  PictureToFits(raw,'tiff',ImgStream,false,pix,piy,binx,biny,bayerpattern,'','','','dcraw',exifkey,exifvalue);
  outr.Free;
  except
    rmsg:='Error converting raw file';
  end;
end
else begin
  rmsg:='No RAW decoder found!';
end;
finally
  exifkey.Free;
  exifvalue.Free;
end;
end;

function PackFits(unpackedfilename,packedfilename: string; out rmsg:string):integer;
var
  j: integer;
  outstr:Tstringlist;
begin
 try
   outstr:=TStringList.Create;
   rmsg:='';
   result:=ExecProcess(fpackcmd+' -O '+packedfilename+' -D -Y '+unpackedfilename,outstr);
   if result<>0 then begin
     for j:=0 to outstr.Count-1 do rmsg:=rmsg+crlf+outstr[j];
   end;
   outstr.Free;
 except
   on E: Exception do begin
     result:=-1;
     rmsg:=E.Message;
   end;
 end;
end;

function UnpackFits(packedfilename: string; var ImgStream:TMemoryStream; out rmsg:string):integer;
{$ifdef mswindows}
var
  j: integer;
  tmpfo: string;
  outstr:Tstringlist;
{$endif}
begin
 try
   ImgStream.Clear;
   {$ifdef mswindows}
   // funpack -S do not work correctly on Windows
   tmpfo:=slash(TmpDir)+'tmpunpack.fits';
   outstr:=TStringList.Create;
   rmsg:='';
   result:=ExecProcess(funpackcmd+' -O '+tmpfo+' -D '+packedfilename,outstr);
   if result=0 then begin
     ImgStream.LoadFromFile(tmpfo);
     DeleteFile(tmpfo);
   end
   else begin
     for j:=0 to outstr.Count-1 do rmsg:=rmsg+crlf+outstr[j];
   end;
   outstr.Free;
   {$else}
   result:=ExecProcessMem(funpackcmd+' -S '+packedfilename,ImgStream,rmsg);
   {$endif}
 except
   on E: Exception do begin
     result:=-1;
     rmsg:=E.Message;
   end;
 end;
end;

end.
