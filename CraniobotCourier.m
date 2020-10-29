%% GUI Initializers
function varargout = CraniobotCourier(varargin)
% CRANIOBOTCOURIER MATLAB code for CraniobotCourier.fig
% Last Modified by GUIDE v2.5 16-Oct-2020 11:05:45

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @CraniobotCourier_OpeningFcn, ...
                   'gui_OutputFcn',  @CraniobotCourier_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);

if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end 
end
function CraniobotCourier_OpeningFcn(hObject, ~, handles, varargin)
% Objective: Initializes the GUI and many of its persistent variables, all of
% which are stored in the 'handles' structue

% Choose default command line output for CraniobotCourier
handles.output = hObject;

%  port variable
handles.port = "";

%  path of G-code file that is to be sent to Craniobot
handles.filePath = {};
handles.lastGc = "";

%  command line cache (used for selecting previously issued commands)
handles.cache = {};

%  2D array to store all probed points of skull in form 
% [x1,y1,z1; 
%  x2 y2 z2;...]
handles.skullPoints = [];

%  "linesToSend" value for Linemode protocol (see g2core wiki)
sb = findobj(gcf,'Tag','sendFileButton');
set(sb,'userdata',4);

%  machine state variable
handles.stat = "DISCONNECTED";

%  CNC position variables
handles.posx = 0;
handles.posy = 0;
handles.posz = 0;
handles.posa = 0;
handles.posb = 0;
handles.posc = 0;
handles.coor = 1; % 1=G54, 2=G55, etc.

% GCode parameters
handles.units = 1; % (0|1 - inch|mm). Default: 1. 

%  state and position textboxs
% Note: 32 is the ASCII character for a space
if handles.units == 1
    units = 'Work Position (mm):';
else
    units = 'Work Position (inch):';
end
coor = strcat('Coord Sys: G',num2str(handles.coor + 53));
xStr = strcat('X:',32,num2str(handles.posx));
yStr = strcat('Y:',32,num2str(handles.posy));
zStr = strcat('Z:',32,num2str(handles.posz));
aStr = strcat('A:',32,num2str(handles.posa));
bStr = strcat('B:',32,num2str(handles.posb));
cStr = strcat('C:',32,num2str(handles.posc));
positionString = {units,coor,xStr,yStr,zStr,aStr,bStr,cStr};
stateString = {'Machine State:',handles.stat};
set(handles.workPositionTextBox,'String',positionString);
set(handles.machineStateTextBox,'String',stateString);

%  program progress bar
handles.line    = 1;
handles.MaxLine = 1;
set(handles.progressBar,'String',{'Progress:',...
    strcat(num2str(100*handles.line/handles.MaxLine),'%')});

% Read in Tool Table
filename = fullfile(pwd,'toolTable.csv');
handles.toolTable = readtable(filename);

% Update handles structure
guidata(hObject, handles);
end
function varargout = CraniobotCourier_OutputFcn(~, ~, handles)
% IDK what this function does, but don't delete it

% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;
end
%% Port Connection
function portMenu_Callback(hObject, ~, handles)
% Objective: Allows user to specify which serial object to connect to

% hObject    handle to portMenu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% portlist   array of all serial object connected to computer
% port       The serial port to communicate with

portList = get(hObject,'String');
% convert to string. If only one line is present in portList, portList(1) will
% just return the first letter of the device, not the first line
portList = string(portList);
handles.port = portList(get(hObject,'Value'));
guidata(gcf,handles);
end
function portMenu_CreateFcn(hObject, ~, ~)
% Objective: Used in the creation of the port menu list 
% hObject    handle to portMenu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
set(hObject,'String',seriallist);
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
end
function connectButton_Callback(hObject, ~, handles)
% Objective: Open/close a serial connection to the Craniobot and enable buttons

% hObject    handle to connectButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% device     handle to serial object (the Craniobot)
try
    device = serial(handles.port,'baudRate',115200,...
                            'Databits', 8,...
                            'StopBits',1,...
                            'Parity','none',...
                            'FlowControl','none',...
                            'ReadAsyncMode','continuous',...
                            'Terminator','LF',...
                            'BytesAvailableFcnMode','terminator',...
                            'BytesAvailableFcn',@BytesAvailable);

    % if button is switched "on"
    if get(hObject,'Value')

        fopen(device);
        % If the serial port fails to open
        if get(device,'Status') ~= 'open'
            instrreset;
            uiwait( errordlg('Missing input parameter...',...
                        'Input Error', 'modal') );
            set(hObject,'Value',0);
        else
            % Change button text and open the serial port
            set(hObject,'String','Close');
            set(handles.machineStateTextBox,'String',["Machine State:","READY"]);
            % store the device handle
            handles.device = device;
            guidata(hObject,handles);

            % enable/disable GUI Elements
            set(findall(handles.MotionButtonsGrp,...
                '-property', 'enable'), 'enable', 'on');
            set(findall(handles.commonCommandsGrp,...
                '-property', 'enable'), 'enable', 'on');
            set(handles.chooseFileButton,'enable','on');
            set(handles.commandLine,'enable','on');
            set(handles.probeCircleMenu,'enable','on');
            set(handles.probeSpiralMenu,'enable','on');
            set(handles.probeDotMenu,'enable','on');
            set(handles.probeWindowMenu,'enable','on');
            set(handles.millMenu,'enable','on');
            set(handles.sucktionSpiralMenu,'enable','on');
            set(handles.portMenu,'enable','off');
            set(handles.refreshButton,'enable','off');

            fprintf(device,'{"ej":1}'); % enter json mode
            fprintf(device,'{"js":1}'); % strict json syntax (for TinyG)
            fprintf(device,'{"jv":5}'); % verbose json feedback
            fprintf(device,'{"sv":1}'); % enable filtered status reports
        end

    % Else, if button is switched "off"
    else
        % Delete serial instrument from memory; change button string
        instrreset; 
        set(gcbo,'String','Open');
        set(handles.machineStateTextBox,'String',["Machine State:","DISCONNECTED"]);

        % enable/disable GUI Elements
        set(findall(handles.MotionButtonsGrp,...
            '-property', 'enable'), 'enable', 'off');
        set(findall(handles.commonCommandsGrp,...
            '-property', 'enable'), 'enable', 'off');
        set(findall(handles.fileManagerGrp,...
                '-property', 'enable'), 'enable', 'off');
        set(handles.commandLine,'enable','off');
        set(handles.probeCircleMenu,'enable','off');
        set(handles.probeSpiralMenu,'enable','off');
        set(handles.probeDotMenu,'enable','off');
        set(handles.probeWindowMenu,'enable','off');
        set(handles.millMenu,'enable','off');
        set(handles.sucktionSpiralMenu,'enable','off');
        set(handles.portMenu,'enable','on');
        set(handles.refreshButton,'enable','on');
    end
    %save changes in data structure
catch ME
    data = cellstr(get(handles.consoleWindow,'String'));
    data{end+1} = ME.identifier;
    data{end+1} = "Serial object appears to be busy, try again";
    set(handles.consoleWindow,'String',data,...
                 'Value',length(data));
    set(handles.connectButton,'Value',0);
    instrreset;
end
    
guidata(hObject,handles);
end
function refreshButton_Callback(~, ~, handles)
% Objective: refreshes the list of serial objects connected to the computer

% hObject    handle to refreshButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
set(handles.portMenu,'String',seriallist,'Value',1);
end
%% Console/Command Line
function consoleWindow_CreateFcn(hObject, ~, ~)
% Objective: Creates the console window

% hObject    handle to consoleWindow (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: listbox controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
set(hObject,'String',{});
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
end
function commandLine_CreateFcn(hObject, ~, ~)
% Objective: Creates the command line

% hObject    handle to commandLine (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
end
function clearWindow_Callback(~, ~, handles)
% Objective: Clears all text from the console window

% Variables:
% hObject    handle to clearWindow (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% consoleWindow     Handle to ui object
consoleWindow = handles.consoleWindow;
set(consoleWindow,'String',{},...
    'Value',1);
end
function commandLine_Callback(hObject, ~, handles)
% hObject    handle to commandLine (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% get handles/set make command line blank. Update cache
device = handles.device;
text = string(get(gcbo,'String'));
handles.cache{end+1} = cellstr(text);
set(gcbo,'String','');

% send command             
fprintf(device,upper(text));
guidata(hObject, handles);
end
%% Jogging 
function linearStepSize_CreateFcn(hObject, ~, ~)
% Objective: Creates the button group that holds the units radio buttons

% hObject    handle to linearStepSize (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
end
function linearStepSize_Callback(hObject, ~, ~)
% Objective: This callback doesn't do anything since all that is needed is the string
% stored in the textbox, which is used in the jogging buttons. But don't delete
% this!
    
% hObject    handle to linearStepSize (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of linearStepSize as text
%        str2double(get(hObject,'String')) returns contents of linearStepSize as a double
str=get(hObject,'String');
if isempty(str2double(str))
    set(hObject,'string',1);
end
end
function linearStepGrp_SelectionChangedFcn(hObject, ~, handles)
% Objective: creates the button group that holds the units and step size
% buttons. Its just used for ease of moving the button group in the future.
    
% hObject    handle to the selected object in linearStepGrp 
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if get(handles.MillimeterButton,'Value')
    fprintf(handles.device,'G21');
    handles.units = 1;
else
    fprintf(handles.device,'G20');
    handles.units = 0;
end
guidata(hObject,handles);
end
function XPlus_Callback(~, ~, handles)
% Objective: Sends a gcode command to move the Craniobot incrimentally in the 
% given axis and direction using the step size from the linearStepGrp

% hObject    handle to XMinus (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% send movement command
stepSize = get(handles.linearStepSize,'String');
command = string(strcat('G91 G0 X',stepSize));
fprintf(handles.device,command); % move to new position
end
function XMinus_Callback(~, ~, handles)
% Objective: Sends a gcode command to move the Craniobot incrimentally in the 
% given axis and direction using the step size from the linearStepGrp

% hObject    handle to XMinus (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% send movement command
stepSize = get(handles.linearStepSize,'String');
command = string(strcat('G91 G0 X-',stepSize));
fprintf(handles.device,command); % move to new position
end
function YPlus_Callback(~, ~, handles)
% Objective: Sends a gcode command to move the Craniobot incrimentally in the 
% given axis and direction using the step size from the linearStepGrp
    
% hObject    handle to YPlus (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% send movement command
stepSize = get(handles.linearStepSize,'String');
command = string(strcat('G91 G0 Y',stepSize));
fprintf(handles.device,command); % move to new position
end
function YMinus_Callback(~, ~, handles)
% Objective: Sends a gcode command to move the Craniobot incrimentally in the 
% given axis and direction using the step size from the linearStepGrp
    
% hObject    handle to YMinus (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% send movement command
stepSize = get(handles.linearStepSize,'String');
command = string(strcat('G91 G0 Y-',stepSize));
fprintf(handles.device,command); % move to new position
end
function ZPlus_Callback(~, ~, handles)
% Objective: Sends a gcode command to move the Craniobot incrimentally in the 
% given axis and direction using the step size from the linearStepGrp
    
% hObject    handle to ZPlus (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% send movement command
stepSize = get(handles.linearStepSize,'String');
command = string(strcat('G91 G0 Z',stepSize));
fprintf(handles.device,command); % move to new position
end
function ZMinus_Callback(~, ~, handles)
% Objective: Sends a gcode command to move the Craniobot incrimentally in the 
% given axis and direction using the step size from the linearStepGrp
    
% hObject    handle to ZMinus (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% send movement command
stepSize = get(handles.linearStepSize,'String');
command = string(strcat('G91 G0 Z-',stepSize));
fprintf(handles.device,command); % move to new position
end
function MillimeterButton_Callback(~, ~, ~)
% This callback doesn't do anything since all that is needed is the state of the
% button. But don't delete it!
end
function InchesButton_Callback(~, ~, ~)
% This callback doesn't do anything since all that is needed is the state of the
% button. But don't delete it!
end
%% Axis Control Commands
function setOriginButton_Callback(~, ~, handles)
% Objective: Sets current position to 0 for all axes

% hObject    handle to setOriginButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% device     handle to serial device (Craniobot)

fprintf(handles.device,'G28.3 X0 Y0 Z0 A0 B0 C0; (Set Origin)');

end
function moveToOriginButton_Callback(~, ~, handles)
% Objective: Moves all axes to their home position

% hObject    handle to moveToOriginButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% device     handle to serial device (Craniobot)

fprintf(handles.device,' G90 G0 Z20; (Move to XY origin)');
fprintf(handles.device,' G90 G0 Y-20; (Move to XY origin)');
fprintf(handles.device,' G90 G0 X0; (Move to XY origin)');
fprintf(handles.device,' G90 G0 Y0; (Move to Z origin)');
end
function clearButton_Callback(~, ~, handles)
% Objective: used to clear alarms

% hObject    handle to clearButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
fprintf(handles.device,' G90 G0 X0 Y0 Z3; (Move to Milling Position)');
%fprintf(handles.device,'{"clear":n}');
%data = cellstr(get(handles.consoleWindow,'String'));
%data{end+1} = '{"clear":n} (Clear Alarms)'; %concatenate newData with the old data
%set(handles.consoleWindow,'String',data,...
%           'Value',length(data));
end
function resetButton_Callback(~, ~, handles)
% hObject    handle to resetButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Send reset command to controller
% Note: 24 is the ASCII character for ctrl-x
fprintf(handles.device,24);
data = cellstr(get(handles.consoleWindow,'String'));
data{end+1} = "Resetting Machine..."; %concatenate newData with the old data
set(handles.consoleWindow,'String',data,...
           'Value',length(data));
end
function resetXButton_Callback(~, ~, handles)
% Objective: Set the current X axis position to 0
% hObject    handle to resetXButton (see GCBO)

% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% device     handle to serial device (Craniobot)

% Set controller position
fprintf(handles.device,'G28.3 X0; (Reset X Axis)');
end
function resetYButton_Callback(~, ~, handles)
% hObject    handle to resetYButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Set controller position
fprintf(handles.device,'G28.3 Y0; (Reset Y Axis)');
end
function resetZButton_Callback(~, ~, handles)
% hObject    handle to resetZButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Set controller position
fprintf(handles.device,'G28.3 Z0; (Reset Z Axis)');
end
function resetAButton_Callback(~, ~, handles)
% hObject    handle to resetAButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Set controller position
fprintf(handles.device,'G28.3 A0; (Reset A Axis)');
end
function resetBButton_Callback(~, ~, handles)
% hObject    handle to resetBButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Set controller position
fprintf(handles.device,'G28.3 B0; (Reset B Axis)');
end
function resetCButton_Callback(~, ~, handles)
% hObject    handle to resetCButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Set controller position
fprintf(handles.device,'G28.3 C0; (Reset C Axis)');
end
function homeAllAxes_Callback(~, ~, handles)
% Objective: Homes all axes and sets values to 0

% hObject    handle to homeAllAxes (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

fprintf(handles.device,'G38.2 Z-90 F100; (Z Auto Down)'); %Z auto down while probing
end
function G55Button_Callback(~, ~, handles)
% hObject    handle to G55Button (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
%
% Tool A uses coord sys P2 (G55). We reserve P1 (G54) as a persistent machine
% coordinate system
offset = handles.G55Text.String;
str = strcat("G10 L2 P2 X0 Y0 Z",offset,"A0 B0 C0");
fprintf(handles.device,str);
fprintf(handles.device,"G55");
end
function G56Button_Callback(~, ~, handles)
% hObject    handle to G56Button (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
%
% Tool B uses coord sys P3 (G56). We reserve P1 (G54) as a persistent machine
% coordinate system
offset = handles.G56Text.String;
str = strcat("G10 L2 P3 X0 Y0 Z",offset,"A0 B0 C0");
fprintf(handles.device,str);
fprintf(handles.device,"G56");
end
function G55Text_Callback(~, ~, ~)
% hObject    handle to G55Text (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of G55Text as text
%        str2double(get(hObject,'String')) returns contents of G55Text as a double
end
function G55Text_CreateFcn(hObject, ~, ~)
% hObject    handle to G55Text (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
end
function G56Text_Callback(~, ~, ~)
% hObject    handle to G56Text (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of G56Text as text
%        str2double(get(hObject,'String')) returns contents of G56Text as a double
end
function G56Text_CreateFcn(hObject, ~, ~)
% hObject    handle to G56Text (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end
end
%% Menus and Program Generation
function ProbingMenu_Callback(~, ~, handles)
% hObject    handle to ProbingMenu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if isempty(handles.skullPoints)
    set(handles.clearSet,'enable','off');
    set(handles.editSet,'enable','off');
else
    set(handles.clearSet,'enable','on');
    set(handles.editSet,'enable','on');
end
end

function probeCircleMenu_Callback(hObject, ~, handles)
% Objective: create window to input probing parameters and generate gcode script 
% hObject    handle to probeCircleMenu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% create new window
fig = figure('Name','Probing Parameters',...
    'Units','pixels',...
    'Position',[200,200,400,150],...
    'NumberTitle','off',...
    'Tag','ProbeCircleWindow',...
    'MenuBar','none',...
    'ToolBar','none');
figHandles = guidata(fig);
handles.skullPoints = [];
guidata(hObject,handles);
% create window elements
figHandles.chamberDiameterLabel = uicontrol(fig,'Style','text',...
    'Units','pixels',...
    'String','Chamber Diameter (mm)',...
    'Position',[5,120,150,20]);
figHandles.chamberDiameterTextBox = uicontrol(fig,'Style','edit',...
    'Units','pixels',...
    'Tag','chamberDiameterTextBox',...
    'String','3',...
    'Position',[200,120,50,20]);
figHandles.chamberLocationLabel = uicontrol(fig,'Style','text',...
    'Units','pixels',...
    'String','Chamber Location (X,Y,Z) (mm)',...
    'Position',[5,90,150,20]);
figHandles.chamberXTextBox = uicontrol(fig,'Style','edit',...
    'Units','pixels',...
    'Tag','chamberXTextBox',...
    'String','1',...
    'Position',[200,90,30,20]);
figHandles.chamberYTextBox = uicontrol(fig,'Style','edit',...
    'Units','pixels',...
    'String','-1',...
    'Position',[240,90,30,20]);
figHandles.chamberZTextBox = uicontrol(fig,'Style','edit',...
    'Units','pixels',...
    'String','0',...
    'Position',[280,90,30,20]);

figHandles.probeSpeedLabel = uicontrol(fig,'Style','text',...
    'Units','pixels',...
    'String','Probe Speed (mm/min)',...
    'Position',[5,60,150,20]);
figHandles.probeSpeedTextBox = uicontrol(fig,'Style','edit',...
    'Units','pixels',...
    'String','30',...
    'Position',[200,60,100,20]);

figHandles.probeSkullButton = uicontrol(fig,'Style','pushbutton',...
    'Units','pixels',...
    'Position',[100,5,200,40],...
    'String','Generate Chamber Probing Program',...
    'Callback',@probeCircleButton_Callback);

guidata(fig,figHandles);
end
function probeSpiralMenu_Callback(hObject, ~, handles)
% Objective: create window to input probing parameters and generate gcode script 
% hObject    handle to probeCircleMenu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% create new window
fig = figure('Name','Probing Parameters',...
    'Units','pixels',...
    'Position',[200,200,400,150],...
    'NumberTitle','off',...
    'Tag','ProbeSpiralWindow',...
    'MenuBar','none',...
    'ToolBar','none');
figHandles = guidata(fig);
handles.skullPoints = [];
guidata(hObject,handles);
% create window elements
figHandles.chamberDiameterSLabel = uicontrol(fig,'Style','text',...
    'Units','pixels',...
    'String','Chamber/Niddle Diameter (mm)',...
    'Position',[5,120,150,20]);
figHandles.chamberDiameterSTextBox = uicontrol(fig,'Style','edit',...
    'Units','pixels',...
    'Tag','chamberDiameterTextBox',...
    'String','1.4',...
    'Position',[200,120,50,20]);
figHandles.chamberSuckTextBox = uicontrol(fig,'Style','edit',...
    'Units','pixels',...
    'String','0.65',...
    'Position',[260,120,50,20]);
figHandles.chamberLocationSLabel = uicontrol(fig,'Style','text',...
    'Units','pixels',...
    'String','Chamber Location (X,Y,Z) (mm)',...
    'Position',[5,90,150,20]);
figHandles.chamberXSTextBox = uicontrol(fig,'Style','edit',...
    'Units','pixels',...
    'Tag','chamberXTextBox',...
    'String','1',...
    'Position',[200,90,30,20]);
figHandles.chamberYSTextBox = uicontrol(fig,'Style','edit',...
    'Units','pixels',...
    'String','-1',...
    'Position',[240,90,30,20]);
figHandles.chamberZSTextBox = uicontrol(fig,'Style','edit',...
    'Units','pixels',...
    'String','0',...
    'Position',[280,90,30,20]);

figHandles.probeSpeedSLabel = uicontrol(fig,'Style','text',...
    'Units','pixels',...
    'String','Probe Speed (mm/min)',...
    'Position',[5,60,150,20]);
figHandles.probeSpeedSTextBox = uicontrol(fig,'Style','edit',...
    'Units','pixels',...
    'String','30',...
    'Position',[200,60,100,20]);

figHandles.probeSkullSButton = uicontrol(fig,'Style','pushbutton',...
    'Units','pixels',...
    'Position',[100,5,200,40],...
    'String','Generate Chamber Probing Program',...
    'Callback',@probeSpiralButton_Callback);

guidata(fig,figHandles);
end
function probeDotMenu_Callback(hObject, ~, handles)
% Objective: create window to input probing parameters and generate gcode script 
% hObject    handle to probeCircleMenu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% create new window
fig = figure('Name','Probing Parameters',...
    'Units','pixels',...
    'Position',[200,200,400,150],...
    'NumberTitle','off',...
    'Tag','ProbeDotWindow',...
    'MenuBar','none',...
    'ToolBar','none');
figHandles = guidata(fig);
handles.skullPoints = [];
guidata(hObject,handles);
% create window elements
figHandles.chamberLocationDLabel = uicontrol(fig,'Style','text',...
    'Units','pixels',...
    'String','Chamber Location (X,Y,Z) (mm)',...
    'Position',[5,90,150,20]);
figHandles.chamberXDTextBox = uicontrol(fig,'Style','edit',...
    'Units','pixels',...
    'Tag','chamberXTextBox',...
    'String','1',...
    'Position',[200,90,30,20]);
figHandles.chamberYDTextBox = uicontrol(fig,'Style','edit',...
    'Units','pixels',...
    'String','-1',...
    'Position',[240,90,30,20]);
figHandles.chamberZDTextBox = uicontrol(fig,'Style','edit',...
    'Units','pixels',...
    'String','0',...
    'Position',[280,90,30,20]);

figHandles.probeSpeedDLabel = uicontrol(fig,'Style','text',...
    'Units','pixels',...
    'String','Probe Speed (mm/min)',...
    'Position',[5,60,150,20]);
figHandles.probeSpeedDTextBox = uicontrol(fig,'Style','edit',...
    'Units','pixels',...
    'String','30',...
    'Position',[200,60,100,20]);
figHandles.probeSkullDButton = uicontrol(fig,'Style','pushbutton',...
    'Units','pixels',...
    'Position',[100,5,200,40],...
    'String','Generate Chamber Probing Program',...
    'Callback',@probeDotButton_Callback);
guidata(fig,figHandles);
end
function probeWindowMenu_Callback(hObject, ~, handles)
% hObject    handle to probeWindowMenu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.skullPoints = [];
guidata(hObject,handles);
fig = figure('Name','Probing Parameters',...
    'Units','pixels',...
    'Position',[200,200,400,100],...
    'NumberTitle','off',...
    'Tag','ProbeWindowWindow',...
    'MenuBar','none',...
    'ToolBar','none');
figHandles = guidata(fig);

% create window elements
figHandles.maxStepLabel = uicontrol(fig,'Style','text',...
    'Units','pixels',...
    'String','Max Step Size (mm)',...
    'Position',[5,60,150,20]);
figHandles.maxStepTextBox = uicontrol(fig,'Style','edit',...
    'Units','pixels',...
    'Tag','maxStepTextBox',...
    'String','10',...
    'Position',[200,60,50,20]);
figHandles.probeSkullButton = uicontrol(fig,'Style','pushbutton',...
    'Units','pixels',...
    'Position',[100,5,200,40],...
    'String','Generate Window Probing Program',...
    'Callback',@probeWindowButton_Callback);

guidata(fig,figHandles);
end
function clearSet_Callback(hObject, ~, handles)
% hObject    handle to clearSet (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.skullPoints = [];
guidata(hObject,handles);
end
function editSet_Callback(hObject, ~, handles)
% hObject    handle to editSet (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% create new window
fig1 = figure('Name','Probed Points',...
               'Units','pixels',...
               'Position',[200,200,200,600],...
               'NumberTitle','off',...
               'Tag','pointList',...
               'MenuBar','none',...
               'ToolBar','none');
fig1Handles = guidata(fig1);
table = uitable('Parent', fig1,...
                'Position', [0 0 200 575],...
                'ColumnName',{'X','Y','Z'},...
                'ColumnWidth',{50,50,50},...
                'ColumnFormat',{'numeric','numeric','numeric'},...
                'ColumnEditable',[true,true,true],...
                'CellEditCallback',@toolTableEdit,...
                'RowName',[],...
                'Data',handles.skullPoints);

fig2 = figure('Name','Point Mapping',...
              'Units','pixels',...
              'Position',[400,200,600,600],...
              'NumberTitle','off',...
              'Tag','pointMap');
fig2Handles = guidata(fig2);
X = handles.skullPoints(:,1);
Y = handles.skullPoints(:,2);
Z = handles.skullPoints(:,3);
scatter3(X,Y,Z);
axis equal
xlabel('X-axis Location (mm)');
ylabel('Y-axis Location (mm)');
zlabel('Z-axis Location (mm)');
title(sprintf('%d Total Points',length(X)));

    function toolTableEdit(~,eventdata,~)
        % Save changes 
        figure(fig1);
        row   = eventdata.Indices(1);
        col   = eventdata.Indices(2);
        input = eventdata.EditData;
        if ~isnumeric(input)
            input = str2double(input);
        end
        handles.skullPoints(row,col) = input;
        % save any changes
        guidata(hObject,handles);
        
        figure(fig2);
        X = handles.skullPoints(:,1);
        Y = handles.skullPoints(:,2);
        Z = handles.skullPoints(:,3);
        scatter3(X,Y,Z);
        axis equal
        xlabel('X-axis Location (mm)');
        ylabel('Y-axis Location (mm)');
        zlabel('Z-axis Location (mm)');
        title(sprintf('%d Total Points',length(X)));
    end

end
function millMenu_Callback(~, ~, ~)
% Objective: create window to input milling parameters and generate gcode script 

% hObject    handle to millMenu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% create new window
fig = figure('Name','Milling Parameters',...
    'Units','pixels',...
    'Position',[200,200,400,180],...
    'NumberTitle','off',...
    'Tag','millWindow',...
    'MenuBar','none',...
    'ToolBar','none');
figHandles = guidata(fig);

% create window elements
figHandles.depthLabel = uicontrol(fig,'Style','text',...
    'Units','pixels',...
    'String','Depth per Pass (mm)',...
    'Position',[5,150,150,20]);
figHandles.depthTextBox = uicontrol(fig,'Style','edit',...
    'Units','pixels',...
    'Tag','depthTextBox',...
    'String','0.05',...
    'Position',[200,150,50,20]);

figHandles.thicknessLabel = uicontrol(fig,'Style','text',...
    'Units','pixels',...
    'String','Skull Thickness (mm)',...
    'Position',[5,120,150,20]);
figHandles.thicknessTextBox = uicontrol(fig,'Style','edit',...
    'Units','pixels',...
    'Tag','thicknessTextBox',...
    'String','1',...
    'Position',[200,120,50,20]);
figHandles.VesselWidthLabel = uicontrol(fig,'Style','text',...
    'Units','pixels',...
    'String','VesselWidth (mm)',...
    'Position',[5,90,150,20]);
figHandles.VesselWidthTextBox = uicontrol(fig,'Style','edit',...
    'Units','pixels',...
    'Tag','thicknessTextBox',...
    'String','0.5',...
    'Position',[200,90,50,20]);
figHandles.feedrateLabel = uicontrol(fig,'Style','text',...
    'Units','pixels',...
    'String','Feedrate (mm/min)',...
    'Position',[5,60,150,20]);
figHandles.feedrateTextBox = uicontrol(fig,'Style','edit',...
    'Units','pixels',...
    'String','20',...
    'Position',[200,60,100,20]);

figHandles.millSkullButton = uicontrol(fig,'Style','pushbutton',...
    'Units','pixels',...
    'Position',[100,10,200,40],...
    'String','Generate Milling Program',...
    'Callback',@millSkullButton_Callback);

guidata(fig,figHandles);
end
function toolMenu_Callback(hObject, ~, handles)
% Objective: Allow user to see/change all tool ofsets
% hObject    handle to toolMenu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% create new window
fig = figure('Name','Tool Table',...
    'Units','pixels',...
    'Position',[200,200,385,575],...
    'NumberTitle','off',...
    'Tag','millWindow',...
    'MenuBar','none',...
    'ToolBar','none');

% get table
filename = fullfile(pwd,'toolTable.csv');
handles.toolTable = readtable(filename);
tData = table2cell(handles.toolTable);
table = uitable('Parent', fig,...
    'Position', [0 0 385 575],...
    'ColumnName',handles.toolTable.Properties.VariableNames,...
    'ColumnWidth',{100,200,80},...
    'ColumnEditable',[false,true,true],...
    'CellEditCallback',@toolTableEdit,...
    'RowName',[],...
    'Data',tData);

    function toolTableEdit(~,eventdata,~)
        % Save changes to csv file
        row = eventdata.Indices(1);
        col = eventdata.Indices(2);
        input = eventdata.EditData;
        if col == 3
            input = str2double(input);
        end
        handles.toolTable(row,col) = {input};
        writetable(handles.toolTable,filename);
    end
% save any changes
guidata(hObject,handles);
end
function probeCircleButton_Callback(~, ~, ~)
% Objective: Take user input values for desired chamber location (in stereotaxic
% coordinates), probe the skull, and record the xyz coordinates of each point to
% produce a tool path 

% hObject    handle to probeSkullButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% @val       axis value stored in text box by user

figHandles = guidata(findobj(0,'Tag','ProbeCircleWindow')); % get handles 
xVal   = str2double(get(figHandles.chamberXTextBox,'String'));
yVal   = str2double(get(figHandles.chamberYTextBox,'String'));
zVal   = str2double(get(figHandles.chamberZTextBox,'String'));
diaVal = str2double(get(figHandles.chamberDiameterTextBox,'String'));
speed  = str2double(get(figHandles.probeSpeedTextBox,'String'));

% if an input is missing, throw an error message
if isempty(xVal) || isempty(yVal) || isempty(zVal) || isempty(diaVal)
    uiwait( errordlg('Missing input parameter...',...
                     'Input Error', 'modal') );
else
    GUI     = findobj(0,'Tag','GUI'); % find GUI since it isn't passed into this function
    handles = guidata(GUI); % get GUI handles (not probe menu handles)
    close;
    probeCircle(diaVal,xVal,yVal,zVal,speed);
end
end
function probeSpiralButton_Callback(~, ~, ~)
% Objective: Take user input values for desired chamber location (in stereotaxic
% coordinates), probe the skull, and record the xyz coordinates of each point to
% produce a tool path 

% hObject    handle to probeSkullButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% @val       axis value stored in text box by user

figHandles = guidata(findobj(0,'Tag','ProbeSpiralWindow')); % get handles 
xVal   = str2double(get(figHandles.chamberXSTextBox,'String'));
yVal   = str2double(get(figHandles.chamberYSTextBox,'String'));
zVal   = str2double(get(figHandles.chamberZSTextBox,'String'));
suckVal = str2double(get(figHandles.chamberSuckTextBox,'String'));
diaVal = str2double(get(figHandles.chamberDiameterSTextBox,'String'));
speed  = str2double(get(figHandles.probeSpeedSTextBox,'String'));

% if an input is missing, throw an error message
if isempty(xVal) || isempty(yVal) || isempty(zVal) || isempty(diaVal)
    uiwait( errordlg('Missing input parameter...',...
                     'Input Error', 'modal') );
else
    GUI     = findobj(0,'Tag','GUI'); % find GUI since it isn't passed into this function
    handles = guidata(GUI); % get GUI handles (not probe menu handles)
    close;
    probeSpiral(suckVal,diaVal,xVal,yVal,zVal,speed);
end
end
function probeDotButton_Callback(~, ~, ~)
% Objective: Take user input values for desired chamber location (in stereotaxic
% coordinates), probe the skull, and record the xyz coordinates of each point to
% produce a tool path 

% hObject    handle to probeSkullButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% @val       axis value stored in text box by user

figHandles = guidata(findobj(0,'Tag','ProbeDotWindow')); % get handles 
xVal   = str2double(get(figHandles.chamberXDTextBox,'String'));
yVal   = str2double(get(figHandles.chamberYDTextBox,'String'));
zVal   = str2double(get(figHandles.chamberZDTextBox,'String'));
speed  = str2double(get(figHandles.probeSpeedDTextBox,'String'));

% if an input is missing, throw an error message
if isempty(xVal) || isempty(yVal) || isempty(zVal)
    uiwait( errordlg('Missing input parameter...',...
                     'Input Error', 'modal') );
else
    GUI     = findobj(0,'Tag','GUI'); % find GUI since it isn't passed into this function
    handles = guidata(GUI); % get GUI handles (not probe menu handles)
    close;
    probeDot(xVal,yVal,zVal,speed);
end
end
function probeWindowButton_Callback(~, ~, ~)
% hObject    handle to probeSkullButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

figHandles = guidata(findobj(0,'Tag','ProbeWindowWindow')); % get handle to window
max_steps  = str2double(get(figHandles.maxStepTextBox,'String'));
if isempty(max_steps)
    uiwait( errordlg('Missing input parameter...',...
                     'Input Error', 'modal') );
else
    close
    pointGen(max_steps);
end
end
function millSkullButton_Callback(~, ~, ~)
% Objective: Take the recorded skull points and generate a milling filling
% accordingly

% hObject    handle to probeSkullButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
figHandles = guidata(findobj(0,'Tag','millWindow')); % get handles 
handles    = guidata(findobj(0,'Tag','GUI'));

if isempty(handles.skullPoints)
    uiwait( errordlg('Skull has not been probed yet.',...
                     'Input Error', 'modal') );
else
    xVals       = handles.skullPoints(:,1);
    yVals       = handles.skullPoints(:,2);
    zVals       = handles.skullPoints(:,3);
    depth       = str2double(get(figHandles.depthTextBox,'String'));
    thickness   = str2double(get(figHandles.thicknessTextBox,'String'));
    VesselWidth = str2double(get(figHandles.VesselWidthTextBox, 'String'));
    feedrate    = str2double(get(figHandles.feedrateTextBox,'String'));
    
    if isempty(depth) || isempty(thickness) || isempty(feedrate) || isempty(VesselWidth)
        uiwait( errordlg('Missing input parameter...',...
                         'Input Error', 'modal') );
    else
        close;
        millProbedPoints(xVals,yVals,zVals,thickness,VesselWidth,depth,feedrate);
    end
end
end
%% File Manager
function chooseFileButton_Callback(hObject, ~, handles)
% Objective: Allow user to choose a G-code (txt) file to be send to the Craniobot

% Key Variables:
% handles    structure with handles and user data (see GUIDATA)

% open dialog box, get file name and path to file on user computer
% Note: must be .txt file
[tempName,tempPath] = uigetfile('.txt');

% if file exists: change text box to file name, enable send/pause/cancel
% buttons, get number of lines
if tempName ~= 0
    handles.filePath = strcat(tempPath,tempName);
    set(handles.fileTextBox,'String',tempName);
    set(handles.sendFileButton,'enable','on');
    fid = fopen(handles.filePath);
    lines = textscan(fid,'%s','delimiter','\n');
    fclose(fid);
    handles.MaxLine = length(lines{1});
    % save changes to handles
    guidata(hObject,handles);
end


end
function sendFileButton_Callback(hObject, ~, handles)
% Objective: Send a G-code file to the Crabiobot using Linemode
% protocol (see g2core wiki).

GUI = findobj(0,'Tag','GUI');
% enable/disable certain features
set(hObject,'enable','off');
set(findall(handles.MotionButtonsGrp,...
    '-property', 'enable'), 'enable', 'off');
set(findall(handles.commonCommandsGrp,...
    '-property', 'enable'), 'enable', 'off');
set(handles.commandLine,'enable','off');
set(handles.pauseButton,'enable','on');
set(handles.abortButton,'enable','on');
% restart line count
handles.line = 0;
% open g-code file
prgmFile = fopen(handles.filePath);
probeFile = false;
set(gcbo,'userdata',4);

% change procedure slightly if running a probing file
if contains(handles.filePath,'probe')
    probeFile = true;
    set(gcbo,'userdata',1);
    handles = guidata(findobj(0,'Tag','GUI')); % get handles 
    guidata(GUI,handles);   
end
% Begin file stream using Linemode Protocol
% Continue protocol unless the file ends or the cancel button is pressed.
% The number of lines to be send to the Craniobot is stored in the Send Button's
% 'userdata' variable.
command = {};
while ~feof(prgmFile) && ~get(handles.abortButton,'Value')
    if probeFile
        while (get(gcbo,'userdata') > 0) && ~get(handles.pauseButton,'Value') && ~feof(prgmFile)% && ~handles.lnRead
            % send line
            command = fgetl(prgmFile);
            fprintf(handles.device,command);
            if feof(prgmFile)
                break;
            end
            set(gcbo,'userdata',get(gcbo,'userdata')-1);
            drawnow(); 
        end
        drawnow();      
    else
        while (get(gcbo,'userdata') > 0) && ~get(handles.pauseButton,'Value') && ~feof(prgmFile)
            % send line
            command = fgetl(prgmFile);
            fprintf(handles.device,command);
            if feof(prgmFile)
                break;
            end
            % decrement number of lines to be sent to arduino
            set(gcbo,'userdata',get(gcbo,'userdata')-1);
            drawnow(); 
        end
        drawnow();
    end
end
fclose(prgmFile);
set(gcbo,'enable','on','Value',0); % reset Send File button
set(handles.abortButton,'Value',0);
% re-enable/disable control buttons when connected
set(findall(handles.MotionButtonsGrp,...
    '-property', 'enable'), 'enable', 'on');
set(findall(handles.commonCommandsGrp,...
    '-property', 'enable'), 'enable', 'on');
set(handles.commandLine,'enable','on');
set(handles.pauseButton,'enable','off');
set(handles.abortButton,'enable','off');
end
function pauseButton_Callback(~, ~, handles)
% Objective: Change the button's text based on its state

% hObject    handle to pauseButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if get(gcbo,'Value')
    set(gcbo,'String','Resume');
    fprintf(handles.device,'!');
else
    set(gcbo,'String','Pause');
    fprintf(handles.device,'~');
end
end
function abortButton_Callback(~, ~, handles)
% Objective: Cancel the rest of the file being sent to the Craniobot

fprintf(handles.device,4); % 4 is the ascii character for ctrl-d
set(handles.pauseButton,'String','Pause','Value',0);
end
%% Keyboard Shortcuts
function GUI_WindowKeyPressFcn(hObject, eventdata, handles)
% hObject    handle to GUI (see GCBO)
% eventdata  structure with the following fields (see MATLAB.UI.FIGURE)
%	Key: name of the key that was pressed, in lower case
%	Character: character interpretation of the key(s) that was pressed
%	Modifier: name(s) of the modifier key(s) (i.e., control, shift) pressed
% handles    structure with handles and user data (see GUIDATA)

shift    = any(strcmp(eventdata.Modifier,'shift'));
control  = any(strcmp(eventdata.Modifier,'control'));
alt      = any(strcmp(eventdata.Modifier,'alt'));
if isempty(eventdata.Modifier)
    % do nothing if no modifier present
elseif shift && ~control && ~alt
    if strcmp(eventdata.Key,'rightarrow')
        XPlus_Callback(hObject, eventdata, handles);
    end
    if strcmp(eventdata.Key,'leftarrow')
        XMinus_Callback(hObject, eventdata, handles);
    end
    if strcmp(eventdata.Key,'uparrow')
        YPlus_Callback(hObject, eventdata, handles);
    end
    if strcmp(eventdata.Key,'downarrow')
        YMinus_Callback(hObject, eventdata, handles);
    end
elseif shift && control && ~alt
    if strcmp(eventdata.Key,'uparrow')
        ZPlus_Callback(hObject, eventdata, handles);
    end
    if strcmp(eventdata.Key,'downarrow')
        ZMinus_Callback(hObject, eventdata, handles);
    end
end
end
function commandLine_KeyPressFcn(hObject, eventdata, handles)
% hObject    handle to commandLine (see GCBO)
% eventdata  structure with the following fields (see MATLAB.UI.CONTROL.UICONTROL)
%	Key: name of the key that was pressed, in lower case
%	Character: character interpretation of the key(s) that was pressed
%	Modifier: name(s) of the modifier key(s) (i.e., control, shift) pressed
% handles    structure with handles and user data (see GUIDATA)
if strcmp(eventdata.Key,'uparrow')
    cl = handles.commandLine;
    str = string(handles.cache{cl.UserData});
    set(cl,'String',str);
    cl.UserData = max(1,cl.UserData - 1);
    guidata(hObject, handles);
elseif strcmp(eventdata.Key,'downarrow')
    cl = handles.commandLine;
    cm = length(handles.cache);
    str = string(handles.cache{cl.UserData});
    set(cl,'String',str);
    cl.UserData = min(cm, cl.UserData + 1);
    guidata(hObject, handles);
end
end
%% Auxiliary
function BytesAvailable(device,~)
% Objective: Computer will automatically read input from serial device
% asynchronously. This function assumes all incoming data is formatted as json

% Variables:
% GUI           Handle to GUI object
% handles       struct containing all handles within the GUI
% json          JSON structure

GUI = findobj(0,'Tag','GUI'); % find GUI since hObject isn't passed into this function
handles = guidata(GUI); % get handles   
consoleWindow = handles.consoleWindow;
newData = fscanf(device); % get input serial data

% If input msg is in json format (first char is {'{'), then analyze the json
if newData(1) == '{'
    json = jsondecode(newData);
    interpretJson(json);
else % print anything else to the console window
    data = cellstr(get(handles.consoleWindow,'String'));
    data{end+1} = newData;
    set(handles.consoleWindow,'String',data,...
                 'Value',length(data));
end
end
function interpretJson(json)
% Objective: This function takes in a json structure, loops through each
% element, and will call functions depending on the elements of the json msg.

% Variables:
% GUI        handle to figure window
% handles    structure with handles and user data of GUI (see GUIDATA)
% json       struct containing name-value pairs or nested structs
% field      data containers within a struct (similar to array element)

GUI = findobj(0,'Tag','GUI'); % find GUI since hObject isn't passed into this function
handles = guidata(GUI); % get handles
% get console text
data = cellstr(get(handles.consoleWindow,'String'));

% get field names of json text
fields = fieldnames(json);

% Look at each field of the json struct and respond accordingly to the
% information
for i = 1:numel(fields)
    % Ignore empty fields
    if ~isempty(json.(fields{i}))
        switch fields{i}
            case 'r'   % Reports
                % If the controller sends a json report, increment the Send Button's 
                % 'userdata' variable (aka, the Linemode protocol's linesToSend
                % variable (used in sendFileButton_Callback)).
                SendButton = findobj(gcf,'Tag','sendFileButton');
                if get(SendButton,'userdata') < 3
                    set(SendButton,'userdata',get(SendButton,'userdata')+1);
                end
                    
                % if the report has children objects, interpret them
                if ~isempty(json.r)
                    interpretJson(json.r); 
                end
            case 'sr'  % Status Reports
                % If the controller sends a status report, update the GUI's 
                % system report window
                statusReportJson(json.sr);
            case 'gc'  % GCode echo
                % Print the interpreted Gcode to the console window
                handles.lastGc = json.gc;
                consoleWindow = handles.consoleWindow;
                data = cellstr(get(consoleWindow,'String'));
                data{end+1} = handles.lastGc;
                set(consoleWindow,'String',data,...
                                  'Value',length(data));
            case 'n'   % Line number response (tinyG).
                % If line number are present in a gcode file, use them to
                % calculate file completion
                handles.line = json.(fields{i});
                set(handles.progressBar,'String',{'Progress:',...
                strcat(num2str(100*handles.line/handles.MaxLine),'%')});
            case 'prb' % Probe Reports
                % If the controller sends a probe report, update the skullPoints array
                updateSkullPoints(json.prb);
            case 'f'   % Footers 
                % Display status (f is a 1x3 array; element 2 is the status number
                text = statusCodes(json.f(2));
                if text ~= "STAT_OK" % suppress 'ok' messages
                    data = cellstr(get(handles.consoleWindow,'String'));
                    data{end+1} = text; %concatenate json-string with the old data
                    set(handles.consoleWindow,'String',data,...
                                 'Value',length(data));
                end
            case 'er'  % Error Messages
                % Print error message on console and update machine status
                text = json.er.msg;
                set(handles.machineStateTextBox,'String',...
                    ["Machine State:","See Error Message"]);
                data = cellstr(get(handles.consoleWindow,'String'));
                data{end+1} = strcat("MSG: ",text); %concatenate json-string with the old data
                set(handles.consoleWindow,'String',data,...
                             'Value',length(data));
            otherwise  % Any other information is probably relevant to the user,
                       % so we print every name-value pair in message
                % iterate through every name-value pair in message
                name = fields{i};
                value = json.(fields{i});
                % if nested json, use recursion to go through the different
                % nests
                if isstruct(value)
                    data{end+1} = sprintf("%-s:",name);
                    % print to console
                    set(handles.consoleWindow,'String',data,...
                         'Value',length(data));
                     
                    interpretJson(value);
                else
                    % convert to string (if not already string) and add to
                    % console text (note, 32 is ascii for 'space'
                    value = string(value);
                    % ignore tool table entry reports since they can be seen in
                    % the tool table menu
                    if contains(name,"tt")
                        continue;
                    end
                    
                    data{end+1} = sprintf("%-s: %+20s",name,value);
                    % print to console
                    set(handles.consoleWindow,'String',data,...
                         'Value',length(data));
                end
        end
    end
end
end
function statusReportJson(SR)
% Objective: take a struct containing a json status report (SR), extract
% the name-value pairs, and update the GUI with relevant information. 

% Variables:
% SR         Status Report struct containing name-value pairs
% handles    structure with handles and user data (see GUIDATA)
% SRFields   list of fields in the status report

handles = guidata(findobj(0,'Tag','GUI')); % get handles 

% get field names of json text
SRfields = fieldnames(SR);

% update the GUI variables that are called in the Status Report
for i = 1:numel(SRfields)
    switch SRfields{i}
        case "line"     % G2core line response
            handles.line = SR.(SRfields{i});
            set(handles.progressBar,'String',{'Progress:',...
            strcat(num2str(100*handles.line/handles.MaxLine),'%')});
        case "coor"
            handles.coor = SR.(SRfields{i});
        case "posx"
            handles.posx = SR.(SRfields{i});
        case "posy"
            handles.posy = SR.(SRfields{i});
        case "posz"
            handles.posz = SR.(SRfields{i});
        case "posa"
            handles.posa = SR.(SRfields{i});
        case "posb"
            handles.posb = SR.(SRfields{i});
        case "posc"
            handles.posc = SR.(SRfields{i});
        case "stat"
            switch SR.(SRfields{i})
                case 0
                    handles.stat = "INITIALIZING";
                case 1
                    handles.stat = "READY";
                case 2
                    handles.stat = "ALARM";
                case 3
                    % Should be program stop, but it means the same thing and
                    % looks better
                    handles.stat = "READY";
                case 4
                    handles.stat = "PROGRAM END";
                case 5
                    handles.stat = "RUN";
                case 6
                    handles.stat = "HOLD";
                case 7
                    handles.stat = "PROBE";
                case 8
                    handles.stat = "CYCLE";
                case 9
                    handles.stat = "HOMING";
                case 10
                    handles.stat = "JOG";
                case 11
                    handles.stat = "INTERLOCK";
                case 12
                    handles.stat = "SHUTDOWN";
                case 13
                    handles.stat = "PANIC";
            end            
        case "units"
            switch SR.(SRfields{i})
                case 0
                    handles.units = 0;
                case 1
                    handles.units = 1;
            end
    end
end

if handles.units == 1
    units = 'Work Position (mm):';
else
    units = 'Work Position (inch):';
end

guidata(findobj(0,'Tag','GUI'), handles);

coor = strcat('Coord Sys: G',num2str(handles.coor + 53));
xStr = strcat('X:',32,num2str(handles.posx));
yStr = strcat('Y:',32,num2str(handles.posy));
zStr = strcat('Z:',32,num2str(handles.posz));
aStr = strcat('A:',32,num2str(handles.posa));
bStr = strcat('B:',32,num2str(handles.posb));
cStr = strcat('C:',32,num2str(handles.posc));
positionString = {units,coor,xStr,yStr,zStr,aStr,bStr,cStr};
stateString = {'Machine State:',handles.stat};
set(handles.workPositionTextBox,'String',positionString);
set(handles.machineStateTextBox,'String',stateString);
    
% Update handles structure
guidata(findobj(0,'Tag','GUI'), handles);
end
function updateSkullPoints(PR)
% Objective: take a struct containing a json probe report (PR), extract the
% name-value pair for the probed z-value, and update the skullPoints array

% Variables:
% PR         struct containing name-value pairs
% handles    structure with handles and user data (see GUIDATA)
% PRFields   list of fields in the probe report

handles = guidata(findobj(0,'Tag','GUI')); % get handles 
% get field names of json text
PRfields = fieldnames(PR);

% update skullPoints array
for i = 1:numel(PRfields)
    switch PRfields{i}
        case "z"
            x = handles.posx;
            y = handles.posy;
            z = PR.(PRfields{i}); % - handles.toolTable.ToolOffset(handles.tool);
            handles.skullPoints(end+1,:) = [x, y, z];
    end
end

% update handles structure
guidata(findobj(0,'Tag','GUI'),handles);
end


% --------------------------------------------------------------------
function sucktionSpiralMenu_Callback(~, ~, ~)
% hObject    handle to sucktionSpiralMenu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
%guidata(hObject,handles);
% create new window
fig = figure('Name','Sucktion Parameters',...
    'Units','pixels',...
    'Position',[200,200,400,220],...
    'NumberTitle','off',...
    'Tag','suckWindow',...
    'MenuBar','none',...
    'ToolBar','none');
figHandles = guidata(fig);
% create window elements
figHandles.SchamberLocationSLabel = uicontrol(fig,'Style','text',...
    'Units','pixels',...
    'String','Chamber Location (X,Y) (mm)',...
    'Position',[5,180,150,20]);
figHandles.SchamberXSTextBox = uicontrol(fig,'Style','edit',...
    'Units','pixels',...
    'Tag','SchamberXSTextBox',...
    'String','1',...
    'Position',[200,180,50,20]);
figHandles.SchamberYSTextBox = uicontrol(fig,'Style','edit',...
    'Units','pixels',...
    'Tag','SchamberYSTextBox',...
    'String','-2.2',...
    'Position',[260,180,50,20]);
figHandles.SchamberDiameterSLabel = uicontrol(fig,'Style','text',...
    'Units','pixels',...
    'String','Chamber/Niddle Diameter (mm)',...
    'Position',[5,150,150,20]);
figHandles.SchamberDiameterSTextBox = uicontrol(fig,'Style','edit',...
    'Units','pixels',...
    'Tag','chamberDiameterTextBox',...
    'String','1.4',...
    'Position',[200,150,50,20]);
figHandles.SchamberSuckTextBox = uicontrol(fig,'Style','edit',...
    'Units','pixels',...
    'String','0.65',...
    'Position',[260,150,50,20]);
figHandles.SdepthLabel = uicontrol(fig,'Style','text',...
    'Units','pixels',...
    'String','Depth per Pass (mm)',...
    'Position',[5,120,150,20]);
figHandles.SdepthTextBox = uicontrol(fig,'Style','edit',...
    'Units','pixels',...
    'Tag','depthTextBox',...
    'String','0.2',...
    'Position',[200,120,50,20]);

figHandles.SthicknessLabel = uicontrol(fig,'Style','text',...
    'Units','pixels',...
    'String','Skull Thickness (mm)',...
    'Position',[5,90,150,20]);
figHandles.SthicknessTextBox = uicontrol(fig,'Style','edit',...
    'Units','pixels',...
    'Tag','thicknessTextBox',...
    'String','2',...
    'Position',[200,90,50,20]);

figHandles.SfeedrateLabel = uicontrol(fig,'Style','text',...
    'Units','pixels',...
    'String','Feedrate (mm/min)',...
    'Position',[5,60,150,20]);
figHandles.SfeedrateTextBox = uicontrol(fig,'Style','edit',...
    'Units','pixels',...
    'String','20',...
    'Position',[200,60,100,20]);

figHandles.spiralSkullButton = uicontrol(fig,'Style','pushbutton',...
    'Units','pixels',...
    'Position',[100,10,200,40],...
    'String','Generate Sucktion Program',...
    'Callback',@sucktionSpiralButton_Callback);

guidata(fig,figHandles);
end
function sucktionSpiralButton_Callback(~, ~, ~)
% Objective: Take the recorded skull points and generate a milling filling
% accordingly

% hObject    handle to probeSkullButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
figHandles = guidata(findobj(0,'Tag','suckWindow')); % get handles 
handles    = guidata(findobj(0,'Tag','GUI'));

    suckVal     = str2double(get(figHandles.SchamberSuckTextBox,'String'));
    diaVal      = str2double(get(figHandles.SchamberDiameterSTextBox,'String'));
%    xVals       = handles.skullPoints(:,1);
%    yVals       = handles.skullPoints(:,2);
%    zVals       = handles.skullPoints(:,3);
    depth       = str2double(get(figHandles.SdepthTextBox,'String'));
    thickness   = str2double(get(figHandles.SthicknessTextBox,'String'));
    feedrate    = str2double(get(figHandles.SfeedrateTextBox,'String'));
    xVal        = str2double(get(figHandles.SchamberXSTextBox,'String'));
    yVal        = str2double(get(figHandles.SchamberYSTextBox,'String'));
    
    if isempty(suckVal) || isempty(diaVal) isempty(depth) || ...
            isempty(thickness) || isempty(feedrate);
        uiwait( errordlg('Missing input parameter...',...
                         'Input Error', 'modal') );
    else
        close;
        sucktionSpiral(suckVal,diaVal,xVal,yVal,thickness,depth,feedrate);
    end
end

% --- Executes on button press in drill_replace.
function drill_replace_Callback(~, ~, handles)
% hObject    handle to drill_replace (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
fprintf(handles.device,' G21; (change to mm)');
fprintf(handles.device,' G90 G0 Z20; (Move the Drill Higher)');
fprintf(handles.device,' G90 G0 Y-20; (Move the Drill Higher)');
fprintf(handles.device,' G90 G0 X-120; (Move the Drill to the side)');
end
% --- Executes on button press in plate_replace.
function plate_replace_Callback(~, ~, handles)
% hObject    handle to plate_replace (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
fprintf(handles.device,' G21; (change to mm)');
fprintf(handles.device,' G90 G0 Z20; (Move the Drill Higher)');
fprintf(handles.device,' G90 G0 Y-20; (Move the Drill Higher)');
fprintf(handles.device,' G90 G0 X-120; (Move the Drill/plate to the side)');
fprintf(handles.device,' G90 G0 Y-70; (Move the Drill Higher)');
end


% --------------------------------------------------------------------
function SucktionMenu_Callback(~, ~, ~)
% hObject    handle to SucktionMenu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
end

% --------------------------------------------------------------------
function MillingMenu_Callback(~, ~, ~)
% hObject    handle to MillingMenu (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
end
