unit cu_plan;

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

{$mode objfpc}{$H+}

interface

uses u_global, u_utils, u_translation, math,
  fu_capture, fu_preview, fu_filterwheel, cu_mount, cu_camera, cu_autoguider,
  ExtCtrls, Classes, SysUtils;

type

T_Steps = array of TStep;

T_Plan = class(TComponent)
  private
    PlanTimer: TTimer;
    StartTimer: TTimer;
    FPlanChange: TNotifyEvent;
    FonMsg,FDelayMsg: TNotifyMsg;
    Fcapture: Tf_capture;
    Fpreview: Tf_preview;
    Ffilter: Tf_filterwheel;
    Fmount: T_mount;
    Fcamera: T_camera;
    Fautoguider: T_autoguider;
    FonStepProgress: TNotifyEvent;
    procedure SetPlanName(val: string);
    procedure NextStep;
    procedure StartStep;
    procedure msg(txt:string; level: integer);
    procedure ShowDelayMsg(txt:string);
    procedure PlanTimerTimer(Sender: TObject);
    procedure StartTimerTimer(Sender: TObject);
    procedure StartCapture;
  protected
    FSteps: T_Steps;
    NumSteps: integer;
    FCurrentStep: integer;
    StepRunning: boolean;
    StepTimeStart,StepDelayEnd: TDateTime;
    FName,FObjectName: string;
    FRunning: boolean;
  public
    constructor Create(AOwner: TComponent);override;
    destructor  Destroy; override;
    procedure Clear;
    function Add(s: TStep):integer;
    procedure Start;
    procedure Stop;
    property Count: integer read NumSteps;
    property CurrentStep: integer read FCurrentStep;
    property Running: boolean read FRunning;
    property PlanName: string read FName write SetPlanName;
    property ObjectName: string read FObjectName write FObjectName;
    property Steps: T_Steps read FSteps;
    property Preview: Tf_preview read Fpreview write Fpreview;
    property Capture: Tf_capture read Fcapture write Fcapture;
    property Mount: T_mount read Fmount write Fmount;
    property Camera: T_camera read Fcamera write Fcamera;
    property Filter: Tf_filterwheel read Ffilter write Ffilter;
    property Autoguider: T_autoguider read Fautoguider write Fautoguider;
    property onMsg: TNotifyMsg read FonMsg write FonMsg;
    property DelayMsg: TNotifyMsg read FDelayMsg write FDelayMsg;
    property onPlanChange: TNotifyEvent read FPlanChange write FPlanChange;
    property onStepProgress: TNotifyEvent read FonStepProgress write FonStepProgress;

end;


implementation

constructor T_Plan.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  NumSteps:=0;
  FRunning:=false;
  PlanTimer:=TTimer.Create(self);
  PlanTimer.Enabled:=false;
  PlanTimer.Interval:=1000;
  PlanTimer.OnTimer:=@PlanTimerTimer;
  StartTimer:=TTimer.Create(self);
  StartTimer.Enabled:=false;
  StartTimer.Interval:=5000;
  StartTimer.OnTimer:=@StartTimerTimer;
  FObjectName:='';
end;

destructor  T_Plan.Destroy;
begin
  Clear;
  inherited Destroy;
end;

procedure T_Plan.SetPlanName(val: string);
begin
  FName:=val;
  if Assigned(FPlanChange) then FPlanChange(self);
end;

procedure T_Plan.msg(txt:string; level: integer);
begin
  if Assigned(FonMsg) then FonMsg(txt,level);
end;

procedure T_Plan.ShowDelayMsg(txt:string);
begin
  if Assigned(FDelayMsg) then FDelayMsg(txt);
end;

procedure  T_Plan.Clear;
var i: integer;
begin
  for i:=0 to NumSteps-1 do FSteps[i].Free;
  SetLength(FSteps,0);
  NumSteps := 0;
  FName:='';
  if Assigned(FPlanChange) then FPlanChange(self);
end;

function T_Plan.Add(s: TStep):integer;
begin
  inc(NumSteps);
  SetLength(FSteps,NumSteps);
  FSteps[NumSteps-1]:=s;
  if Assigned(FPlanChange) then FPlanChange(self);
  result:=NumSteps-1;
end;

procedure T_Plan.Start;
begin
  FRunning:=true;
  if FObjectName<>'' then
     msg(Format(rsObjectStartP, [FObjectName, FName]),1)
  else
     msg(Format(rsStartPlan, [FName]),1);
  FCurrentStep:=-1;
  NextStep;
end;

procedure T_Plan.Stop;
var p: TStep;
begin
  p:=FSteps[CurrentStep];
  if p<>nil then begin
    p.donecount:=CurrentDoneCount;
  end;
  FRunning:=false;
  if Capture.Running then Capture.BtnStartClick(Self);
end;

procedure T_Plan.NextStep;
begin
  PlanTimer.Enabled:=false;
  FlatWaitDusk:=false;
  FlatWaitDawn:=false;
  if assigned(FonStepProgress) then FonStepProgress(self);
  inc(FCurrentStep);
  if FCurrentStep<NumSteps then begin
    StartStep;
    wait(2);
    PlanTimer.Enabled:=true;
  end
  else begin
    FRunning:=false;
    PlanTimer.Enabled:=false;
    FCurrentStep:=-1;
    CurrentStepName:='';
    if FObjectName<>'' then
      msg(Format(rsObjectPlanFi, [FObjectName, FName]),1)
    else
      msg(Format(rsPlanFinished, [FName]),1);
  end;
end;

procedure T_Plan.StartStep;
var p: TStep;
begin
  StepRunning:=true;
  p:=FSteps[CurrentStep];
  if p<>nil then begin
    CurrentStepNum:=CurrentStep;
    CurrentDoneCount:=p.donecount;
    if CurrentDoneCount>=p.count then begin
       // step already complete
       msg('Step '+p.description+' complete',2);
       exit;
    end;
    if p.exposure>=0 then Fcapture.ExposureTime:=p.exposure;
    Fcapture.Binning.Text:=p.binning_str;
    if hasGainISO then
      Fcapture.ISObox.ItemIndex:=p.gain
    else
      Fcapture.GainEdit.Value:=p.gain;
    if p.fstop<>'' then Fcapture.Fnumber.Text:=p.fstop;
    Fcapture.SeqNum.Value:=p.count;
    Fcapture.SeqCount:=CurrentDoneCount+1;
    Fcapture.FrameType.ItemIndex:=ord(p.frtype);
    Fcapture.CheckBoxDither.Checked:=p.dither;
    Fcapture.DitherCount.Value:=p.dithercount;
    Fcapture.CheckBoxFocus.Checked:=p.autofocus;
    Fcapture.FocusCount.Value:=p.autofocuscount;
    if p.autofocusstart then Fcapture.FocusNow:=true;
    Ffilter.Filters.ItemIndex:=p.filter;
    Ffilter.FiltersChange(self);
    if p.frtype=FLAT then begin
      if words(p.description,'',1,1)='Dusk' then
        FlatWaitDusk:=true;
      if words(p.description,'',1,1)='Dawn' then
        FlatWaitDawn:=true;
    end;
    Wait;
    if not FRunning then exit;
    StepTimeStart:=now;
    msg(Format(rsStartStep, [p.description_str]),1);
    CurrentStepName:=p.description;
    ShowDelayMsg('');
    StartCapture;
  end;
end;


procedure T_Plan.PlanTimerTimer(Sender: TObject);
var p: TStep;
begin
 if FRunning then begin
   p:=FSteps[CurrentStep];
   if p<>nil then begin
     // store image count
     if p.donecount<>CurrentDoneCount then begin
        p.donecount:=CurrentDoneCount;
        if assigned(FonStepProgress) then FonStepProgress(self);
     end;
   end;
   StepRunning:=Capture.Running;
   if not StepRunning then begin
       NextStep;
   end;
 end
 else begin
    PlanTimer.Enabled:=false;
    FCurrentStep:=-1;
    msg(Format(rsPlanStopped, [FName]),1);
    ShowDelayMsg('');
 end;
end;


procedure T_Plan.StartTimerTimer(Sender: TObject);
begin
 StartTimer.Enabled:=false;
 StartCapture;
end;

procedure T_Plan.StartCapture;
begin
 if preview.Running then begin
     msg(rsStopPreview,2);
     camera.AbortExposure;
     preview.stop;
     StartTimer.Enabled:=true;
     exit;
 end;
  Fcapture.BtnStartClick(nil);
end;

end.

