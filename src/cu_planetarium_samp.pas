unit cu_planetarium_samp;

{$mode objfpc}{$H+}

{                                        
Copyright (C) 2015 Patrick Chevalley

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
{
  client to connect to SAMP hub and peer.
}

interface

uses u_global, u_utils, cu_planetarium, cu_sampclient, cu_sampserver, Classes, SysUtils,
    FileUtil, ExtCtrls, Forms;

type

  TPlanetarium_samp = class(TPlanetarium)
  private
    SampClient : TSampClient;
    ClientChangeTimer: TTimer;
    procedure ClientChangeTimerTimer(Sender: TObject);
    procedure ClientChange(Sender: TObject);
    procedure ClientDisconnected(Sender: TObject);
    procedure coordpointAtsky(cra,cdec:double);
    procedure ImageLoadFits(image_name,image_id,url:string);
  public
    Constructor Create;
    Destructor Destroy; override;
    procedure Connect(cp1: string; cp2:string=''); override;
    procedure Disconnect; override;
    function ShowImage(fn: string):boolean; override;
  end;


implementation

/////////////////// TPlanetarium_samp ///////////////////////////

Constructor TPlanetarium_samp.Create ;
begin
inherited Create;
ClientChangeTimer:=TTimer.Create(nil);
ClientChangeTimer.Enabled:=false;
ClientChangeTimer.Interval:=100;
ClientChangeTimer.OnTimer:=@ClientChangeTimerTimer;
end;

Destructor TPlanetarium_samp.Destroy;
begin
  ClientChangeTimer.Enabled:=false;
  ClientChangeTimer.Free;
  if SampClient<>nil then Disconnect;
  inherited Destroy;
end;

procedure TPlanetarium_samp.Connect(cp1: string; cp2:string='');
begin
 SampClient:=TSampClient.Create;
 SampClient.appname:='ccdciel';
 SampClient.appdesc:='CCDciel image capture software';
 SampClient.appicon:='http://a.fsdn.com/allura/p/ccdciel/icon';
 SampClient.appdoc:='http://sourceforge.net/projects/ccdciel/';
 SampClient.onClientChange:=@ClientChange;
 SampClient.onDisconnect:=@ClientDisconnected;
 SampClient.oncoordpointAtsky:=@coordpointAtsky;
 SampClient.onImageLoadFits:=@ImageLoadFits;
 if SampClient.SampReadProfile then begin
   if not SampClient.SampHubConnect then DisplayMessage('SAMP '+SampClient.LastError);
   if SampClient.Connected then begin
    DisplayMessage('SAMP connected to '+SampClient.HubUrl);
     if not SampClient.SampHubSendMetadata then DisplayMessage('SAMP '+SampClient.LastError);
     if not SampClient.SampSubscribe(true,false,false) then DisplayMessage('SAMP '+SampClient.LastError);
     DisplayMessage('SAMP listen on port '+inttostr(SampClient.ListenPort));
     FStatus:=true;
     if assigned(FonConnect) then FonConnect(self);
   end;
 end else begin
     DisplayMessage('SAMP '+SampClient.LastError);
     FStatus:=false;
     if assigned(FonDisconnect) then FonDisconnect(self);
     Terminate;
 end;
end;

procedure TPlanetarium_samp.Disconnect;
begin
 FStatus:=false;
 if SampClient<>nil then begin;
   SampClient.SampHubDisconnect;
 end;
 if assigned(FonDisconnect) then FonDisconnect(self);
 Terminate;
end;

procedure TPlanetarium_samp.ClientDisconnected(Sender: TObject);
begin
 FStatus:=false;
 if assigned(FonDisconnect) then FonDisconnect(self);
 Terminate;
end;

procedure TPlanetarium_samp.coordpointAtsky(cra,cdec:double);
begin
   FRecvData:='coordpointAtsky '+formatfloat(f5,cra)+' '+formatfloat(f5,cdec);
   Fra:=cra/15;
   Fde:=cdec;
   if assigned(FonReceiveData) then FonReceiveData(FRecvData);
end;

procedure TPlanetarium_samp.ImageLoadFits(image_name,image_id,url:string);
begin
   // not subscribed
   DisplayMessage('ImageLoadFits '+image_name+chr(13)+image_id+chr(13)+url);
end;

procedure TPlanetarium_samp.ClientChange(Sender: TObject);
begin
  ClientChangeTimer.Enabled:=true;
end;

procedure TPlanetarium_samp.ClientChangeTimerTimer(Sender: TObject);
var i,n: integer;
begin
  ClientChangeTimer.Enabled:=false;
  if SampClient.SampHubGetClientList then begin
     n:=SampClient.Clients.Count;
     if n=0 then DisplayMessage('No SAMP clients')
            else DisplayMessage('SAMP clients: '+inttostr(n));
     {
     if n=0 then DisplayMessage('No SAMP clients')
     else for i:=0 to n-1 do begin
        DisplayMessage(SampClient.Clients[i]+', '+SampClient.ClientNames[i]+', '+SampClient.ClientDesc[i]);
     end;}
  end
  else DisplayMessage('SAMP error '+inttostr(SampClient.LastErrorcode)+SampClient.LastError);
end;

function TPlanetarium_samp.ShowImage(fn: string):boolean;
var client,imgname,imgid,url: string;
begin
  client:=''; // broadcast
  imgname:=ExtractFileNameOnly(fn);
  imgid:='ccdciel_'+imgname;
  url:='file://'+fn;
  SampClient.SampSendImageFits(client,imgname,imgid,url);
end;

end.
