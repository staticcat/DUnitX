unit DUnitX.Timeout;

interface

uses
  Classes;

type
  ITimeout = interface(IUnknown)
    ['{0A380F7B-9CEE-4FD7-9D86-60CE05B97C1A}']
    procedure Stop;
  end;

  function InitialiseTimeout(const ATime: cardinal): ITimeout;

implementation

uses
  DUnitX.TestFramework,
  DUnitX.Utils,
  Windows;

// The following TimeOut code is based on the code found at
// https://code.google.com/p/delphitimeouts/
// DelphiTimeouts version 1.1
// Copyright (c) 2007-2008 Szymon Jachim

type
  TTimeoutThread = class(TThread)
  private
    procedure TimeoutThread;
  public
    ThreadHandle: Cardinal;
    Timeout: Cardinal;
    procedure Execute; override;
  end;

  TTimeout = class(TInterfacedObject, ITimeout)
  private
    FTimeoutThread: TTimeoutThread;
  public
    constructor Create(const ATimeout: Cardinal; AThreadHandle: THandle);
    destructor Destroy; override;

    procedure Stop;
  end;

function InitialiseTimeout(const ATime: cardinal): ITimeout;
var
  ThisThreadHandle: THandle;
begin
  DuplicateHandle(GetCurrentProcess, GetCurrentThread, GetCurrentProcess, @ThisThreadHandle, 0, True, DUPLICATE_SAME_ACCESS);
  Result := TTimeout.Create(ATime, ThisThreadHandle);
end;

procedure RaiseTimeOutException;
begin
  raise ETimedOut.Create('Operation Timed Out');
end;

procedure TTimeoutThread.TimeoutThread;
var
  Ctx: _CONTEXT;
begin
  SuspendThread(ThreadHandle);
  Ctx.ContextFlags := CONTEXT_FULL;
  GetThreadContext(ThreadHandle, Ctx);
  Ctx.Eip := Cardinal(@RaiseTimeOutException);
  SetThreadContext(ThreadHandle, Ctx);
  ResumeThread(ThreadHandle);
end;

{ TTimeout }

procedure TTimeout.Stop;
begin
  FTimeoutThread.Terminate;
end;

constructor TTimeout.Create(const ATimeout: Cardinal; AThreadHandle: THandle);
begin
  FTimeoutThread := TTimeoutThread.Create(true);
  FTimeoutThread.FreeOnTerminate := false;
  FTimeoutThread.ThreadHandle := AThreadHandle;
  FTimeoutThread.Timeout := ATimeout;
  FTimeoutThread.Resume;
end;

destructor TTimeout.Destroy;
begin
  //Unwinding and we need to stop the thread, as it may still raise an exception
  Stop;
  FTimeoutThread.WaitFor;
  FTimeoutThread.Free;
  inherited;
end;

{ TTimeoutThread }

procedure TTimeoutThread.Execute;
var
  startTime : Cardinal;
  elaspedTime : Cardinal;
begin
  inherited;

  //Get the tickcount so that we leave timing up to the system.
  startTime := GetTickCount;

  repeat
    //Give some time back to the system to process the test.
    Sleep(1);

    if Terminated then
      Break;

    elaspedTime := GetElapsedTime(startTime);
  until (elaspedTime >= Timeout);

  //If we haven't been terminated then we have timed out.
  if not Terminated then
    TimeoutThread;
end;


end.
