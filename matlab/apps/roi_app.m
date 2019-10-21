function varargout = roi_app(varargin)
% ROI_APP MATLAB code for roi_app.fig
%      ROI_APP, by itself, creates a new ROI_APP or raises the existing
%      singleton*.
%
%      H = ROI_APP returns the handle to a new ROI_APP or the handle to
%      the existing singleton*.
%
%      ROI_APP('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in ROI_APP.M with the given input arguments.
%
%      ROI_APP('Property','Value',...) creates a new ROI_APP or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before roi_app_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to roi_app_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help roi_app

% Last Modified by GUIDE v2.5 05-Apr-2019 16:33:17

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @roi_app_OpeningFcn, ...
                   'gui_OutputFcn',  @roi_app_OutputFcn, ...
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
% End initialization code - DO NOT EDIT


% --- Executes just before roi_app is made visible.
function roi_app_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to roi_app (see VARARGIN)

% Choose default command line output for roi_app
handles.output = hObject;
handles.parent = NaN;
handles.Trck = NaN;

if isa(varargin{1},'trhandles')
    Trck = varargin{1};
else
    handles.parent = varargin{1};  
    Trck = handles.parent.Trck;
end

handles = set_Trck(handles,Trck);

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes roi_app wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = roi_app_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;


% --- Executes on button press in RestBlackButton.
function RestBlackButton_Callback(hObject, eventdata, handles)
% hObject    handle to RestBlackButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

handles.Trck.Masks.roi = false(size(handles.Trck.Masks.roi));
handles = update(handles);
guidata(handles.figure1,handles);

% --- Executes on button press in ResetWhiteButton.
function ResetWhiteButton_Callback(hObject, eventdata, handles)
% hObject    handle to ResetWhiteButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

handles.Trck.Masks.roi = true(size(handles.Trck.Masks.roi));
handles = update(handles);
guidata(handles.figure1,handles);

% --- Executes on selection change in ShapeSelect.
function ShapeSelect_Callback(hObject, eventdata, handles)
% hObject    handle to ShapeSelect (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns ShapeSelect contents as cell array
%        contents{get(hObject,'Value')} returns selected item from ShapeSelect


% --- Executes during object creation, after setting all properties.
function ShapeSelect_CreateFcn(hObject, eventdata, handles)
% hObject    handle to ShapeSelect (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% --- Executes on button press in AddToROIButton.
function AddToROIButton_Callback(hObject, eventdata, handles)
% hObject    handle to AddToROIButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

new = get_region(handles);
handles.Trck.Masks.roi = shift_roi(handles) | new;
handles.Trck.Masks.vshift = 0;
handles.Trck.Masks.hshift = 0;
handles = update(handles);

% --- Executes on button press in RemoveFromROIButton.
function RemoveFromROIButton_Callback(hObject, eventdata, handles)
% hObject    handle to RemoveFromROIButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

new = get_region(handles);
handles.Trck.Masks.roi = shift_roi(handles) & ~new;
handles.Trck.Masks.vshift = 0;
handles.Trck.Masks.hshift = 0;
handles = update(handles);

% --- Executes on button press in ImportButton.
function ImportButton_Callback(hObject, eventdata, handles)
% hObject    handle to ImportButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

defPath = '~/.tracking/masks/';
if ~isdir(defPath)
    mkdir(defPath);
end

[FileName,PathName] = uigetfile('*','Select mask file:',defPath);


try
    load([PathName,filesep,FileName],'roimsk');
catch
    report('E','Failed to load file');
    return
end
    
if ~exist('roimsk','var')
    report('E','No msk variable in file');
    return
end

handles.Trck.Masks.roi = roimsk;
handles.Trck.Masks.hshift = 0;
handles.Trck.Masks.vshift = 0;

handles = update(handles);


% --- Executes on button press in SaveButton.
function SaveButton_Callback(hObject, eventdata, handles)
% hObject    handle to SaveButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

handles.Trck.Masks.roi = shift_roi(handles);
handles.Trck.Masks.hshift = 0;
handles.Trck.Masks.vshift = 0;
handles.Trck.save_masks;
handles.Trck.save;

if isfield(handles,'scale_tool_h')
    delete(handles.scale_tool_h)
    handles.scale_tool_h = [];
else
    handles.scale_tool_h = [];
end

handles = update(handles);

delete(handles.figure1);

% --- Executes on button press in MoveUpButton.
function MoveUpButton_Callback(hObject, eventdata, handles)
% hObject    handle to MoveUpButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

if ~isfield(handles.Trck.Masks,'vshift')
    handles.Trck.Masks.vshift = 0;
end
handles.Trck.Masks.vshift = handles.Trck.Masks.vshift-1;
handles = update(handles);

% --- Executes on button press in MoveRightButton.
function MoveRightButton_Callback(hObject, eventdata, handles)
% hObject    handle to MoveRightButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

if ~isfield(handles.Trck.Masks,'hshift')
    handles.Trck.Masks.hshift = 0;
end
handles.Trck.Masks.hshift = handles.Trck.Masks.hshift+1;
handles = update(handles);

% --- Executes on button press in MoveLeftButton.
function MoveLeftButton_Callback(hObject, eventdata, handles)
% hObject    handle to MoveLeftButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

if ~isfield(handles.Trck.Masks,'hshift')
    handles.Trck.Masks.hshift = 0;
end
handles.Trck.Masks.hshift = handles.Trck.Masks.hshift-1;
handles = update(handles);

% --- Executes on button press in MoveDnButton.
function MoveDnButton_Callback(hObject, eventdata, handles)
% hObject    handle to MoveDnButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

if ~isfield(handles.Trck.Masks,'vshift')
    handles.Trck.Masks.vshift = 0;
end
handles.Trck.Masks.vshift = handles.Trck.Masks.vshift+1;
handles = update(handles);

% --- Executes on button press in ReflectionCheckBox.
function ReflectionCheckBox_Callback(hObject, eventdata, handles)
% hObject    handle to ReflectionCheckBox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

handles = update(handles);

% Hint: get(hObject,'Value') returns toggle state of ReflectionCheckBox

function handles = set_Trck(handles,Trck)

if isempty(Trck.Masks)
    Trck.Masks(1).roi = true(size(Trck.get_bg));
    Trck.Masks.reflection = true(size(Trck.Masks.roi)); 
    Trck.Masks.tracking = Trck.Masks.roi;
    Trck.Masks.hshift = 0;
    Trck.Masks.vshift = 0;
end

handles.Trck = Trck;
handles.user_colony_labels = Trck.colony_labels;

% set frame selector values and show first frame
cla(handles.ImageAxes);
handles.image_h = image(handles.ImageAxes,Trck.get_bg);
handles.image_h.CData=handles.Trck.get_bg;
axis off
hold on
axis image


scale = handles.Trck.get_param('geometry_rscale');
lfs = handles.Trck.get_param('geometry_scale_tool_meas');

set(handles.ScaleResultLabel,'String',['Scale: ',num2str(1/(1000*scale),'%.1f'),' pix/mm']);
set(handles.ScaleField,'String',num2str(lfs));



if strcmp(Trck.get_param('geometry_scale_tool'),'Circle')
    handles.ScaleLabel.String = 'Diameter:';
else
    handles.ScaleLabel.String = 'Length:';
end

handles.MultiColonyCheckBox.Enable='on';

if Trck.get_param('geometry_Ncolonies')==1
    handles.MultiColonyCheckBox.Value = 0;
    handles.MultiColonyNumbering.Enable = 'off';
else
    handles.MultiColonyCheckBox.Value = 1;
    handles.MultiColonyNumbering.Enable = 'on';
end


c = cellstr(get(handles.MultiColonyNumbering,'String'));
if ismember(Trck.get_param('geometry_multi_colony_numbering'),c)
    handles.MultiColonyNumbering.Value = find(strcmp(Trck.get_param('geometry_multi_colony_numbering'),c));
else
    handles.MultiColonyNumbering.Value = 1;
end

handles.CircShiftField.String = num2str(Trck.get_param('geometry_multi_colony_circ_shift'));


nummeth = c{get(handles.MultiColonyNumbering,'Value')} ;

if strcmp(nummeth,'Clockwise')
    handles.CircShiftField.Enable = 'on';
else
    handles.CircShiftField.Enable = 'off';
end


handles = update(handles);

handles=update_colony_mask(handles);

guidata(handles.figure1,handles);

function handles = update_scale(handles)

if ~isfield(handles,'scale_tool')
    return
end

L = str2double(get(handles.ScaleField,'String'));
Ellipse = [];
arenacenter = [0,0];

if strcmp(handles.scale_tool,'Line')
    try
        handles.position = getPosition(handles.scale_tool_h);
    catch
    end
    Dpix = handles.position(1,:)-handles.position(2,:);
    Dpix = sqrt(sum(Dpix.^2));
    scale = L/(1000*Dpix);
elseif strcmp(handles.scale_tool,'Circle')
    try
        handles.position = getVertices(handles.scale_tool_h);
    catch
    end
    ellipse_t = fit_ellipse(handles.position(:,1),handles.position(:,2));
    Ellipse.position = handles.position;
    Ellipse.Cx = ellipse_t.X0;
    Ellipse.Cy = ellipse_t.Y0;
    Ellipse.Rx = ellipse_t.a;
    Ellipse.Ry = ellipse_t.b;
    Ellipse.alpha = ellipse_t.phi;
    
    %A = max(Ellipse.Rx,Ellipse.Ry);
    %B = min(Ellipse.Rx,Ellipse.Ry);
    %eccentricity = sqrt(1-(B/A)^2);
    arenacenter = [Ellipse.Cx Ellipse.Cy];
    Dpix = (Ellipse.Rx+Ellipse.Ry);
    scale = L/(1000*Dpix);
end

set(handles.ScaleResultLabel,'String',['Scale: ',num2str(1/(1000*scale),'%.1f'),' pix/mm']);

handles.Trck.set_param('geometry_rscale',scale);
handles.Trck.set_param('geometry_arenacenter',arenacenter);
handles.Trck.set_param('geometry_scale_tool', handles.scale_tool);
handles.Trck.set_param('geometry_scale_tool_meas',L);
handles.Trck.set_param('geometry_Ellipse',Ellipse);
sqsz = 50*(handles.Trck.get_param('geometry_scale0')/handles.Trck.get_param('geometry_rscale'));
handles.Trck.set_param('sqsz',2*round(sqsz/2));

guidata(handles.figure1,handles);
%uiresume(handles.figure1);


function handles = update(handles)

roi = shift_roi(handles);
% 
% if handles.ReflectionCheckBox.Value
%     handles.Trck.Masks.tracking = roi.*handles.Trck.Masks.reflection;
% else
     handles.Trck.Masks.tracking = roi;
% end

im = imdivide(handles.Trck.get_bg,uint8(2*(1-handles.Trck.TrackingMask)+handles.Trck.TrackingMask));
set(handles.image_h,'CData',im);

handles.Trck.Masks.roi = uint8(handles.Trck.Masks.roi);
handles.Trck.Masks.reflection = uint8(handles.Trck.Masks.reflection);
handles.Trck.Masks.tracking = uint8(handles.Trck.Masks.tracking);
if isfield(handles.Trck.Masks,'colony')
    handles.Trck.Masks.colony = uint8(handles.Trck.Masks.colony);
else
    handles.Trck.Masks.colony = handles.Trck.Masks.roi;
end
handles=update_colony_mask(handles);

guidata(handles.figure1,handles);

function new = get_region(handles)


hControls = findobj(handles.figure1,'Enable','on');
setUicontrols(hControls,'Enable','off');

if isfield(handles,'tool_h')
    delete(handles.tool_h);
end

tools = cellstr(get(handles.ShapeSelect,'String'));
tool = tools{get(handles.ShapeSelect,'Value')};

switch tool
    case 'Ellipse'
        handles.tool_h = imellipse(handles.ImageAxes);
    case 'Rectangle'
        handles.tool_h = imrect(handles.ImageAxes);
    case 'Polygon'
        handles.tool_h = impoly(handles.ImageAxes);
    case 'Free Hand'
        handles.tool_h = imfreehand(handles.ImageAxes);
    otherwise
        error('wrong tool')
end

setColor(handles.tool_h,'green')

position = wait(handles.tool_h);

if ~isempty(position)
    % wait for double-click and exit if echap is pressed
    % % %
    delete(handles.tool_h)
    if strcmp(tool,'Rectangle')
        Position(1,:) = position(1:2);
        Position(2,:) = position(1:2)+[position(3) 0];
        Position(3,:) = position(1:2)+[position(3) position(4)];
        Position(4,:) = position(1:2)+[0 position(4)];
        position = Position;
    elseif strcmp(tool,'Ellipse')
        % The default resolution of the ellipse is pretty bad, let's
        % improve it a bit
        ellipse_t = fit_ellipse(position(:,1),position(:,2));
        Ellipse.Cx = ellipse_t.X0;
        Ellipse.Cy = ellipse_t.Y0;
        Ellipse.Rx = ellipse_t.a;
        Ellipse.Ry =ellipse_t.b;
        Ellipse.alpha = ellipse_t.phi;
        Ellipse.R_alpha = [cos(Ellipse.alpha), -sin(Ellipse.alpha); sin(Ellipse.alpha), cos(Ellipse.alpha)];
        Npoints = 500;
        theta = linspace(0,2*pi,Npoints);
        R = repmat([Ellipse.Cx;Ellipse.Cy],1,Npoints) + Ellipse.R_alpha * [Ellipse.Rx * cos(theta); Ellipse.Ry* sin(theta)];
        R=R';
        position = R;
    end
    new = poly2mask(position(:,1),position(:,2),size(handles.Trck.get_bg,1),size(handles.Trck.get_bg,2));
    new  = repmat(new,1,1,3);
else
    new = zeros(size(Trck.TrackingMask));
end

setUicontrols(hControls,'Enable','on');

function roi = shift_roi(handles)


roi = handles.Trck.Masks.roi;
if isfield(handles.Trck.Masks,'hshift') && handles.Trck.Masks.hshift>0
    roi(:,handles.Trck.Masks.hshift+1:end,:) = roi(:,1:end-handles.Trck.Masks.hshift,:);
    roi(:,1:handles.Trck.Masks.hshift,:) = false;
elseif isfield(handles.Trck.Masks,'hshift') && handles.Trck.Masks.hshift<0
    roi(:,1:end+handles.Trck.Masks.hshift,:) = roi(:,-handles.Trck.Masks.hshift+1:end,:);
    roi(:,end+handles.Trck.Masks.hshift+1:end,:) = false;
end
if isfield(handles.Trck.Masks,'vshift') && handles.Trck.Masks.vshift>0
    roi(handles.Trck.Masks.vshift+1:end,:,:) = roi(1:end-handles.Trck.Masks.vshift,:,:);
    roi(1:handles.Trck.Masks.vshift,:,:) = false;
elseif isfield(handles.Trck.Masks,'vshift') && handles.Trck.Masks.vshift<0
    roi(1:end+handles.Trck.Masks.vshift,:,:) = roi(-handles.Trck.Masks.vshift+1:end,:,:);
    roi(end+handles.Trck.Masks.vshift+1:end,:,:) = false;
end


% --- Executes on button press in CircleScaleButton.
function CircleScaleButton_Callback(hObject, eventdata, handles)
% hObject    handle to CircleScaleButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

handles.ScaleLabel.String = 'Diameter:';

if isfield(handles,'scale_tool_h')
    delete(handles.scale_tool_h)
end


handles.scale_tool_h = imellipse(handles.ImageAxes);
set(handles.scale_tool_h,'UserData','imellipse');
setColor(handles.scale_tool_h,'b');
handles.scale_tool = 'Circle';
set(zoom(handles.ImageAxes),'ActionPostCallback',@(x,y) ZoomCallbackFcn(handles.ImageAxes));
addNewPositionCallback(handles.scale_tool_h,@(pos) update_scale(handles));
handles = update_scale(handles);
wait(handles.scale_tool_h);
delete(handles.scale_tool_h);
guidata(handles.figure1,handles);

% --- Executes on button press in LineScaleButton.
function LineScaleButton_Callback(hObject, eventdata, handles)
% hObject    handle to LineScaleButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

handles.ScaleLabel.String = 'Length:';

if isfield(handles,'scale_tool_h')
    delete(handles.scale_tool_h)
end

handles.scale_tool_h = imline(handles.ImageAxes);
set(handles.scale_tool_h,'UserData','imline');
setColor(handles.scale_tool_h,'b');
% make sure the point is included in the image
fcn = makeConstrainToRectFcn('imline',get(handles.ImageAxes,'XLim'),get(handles.ImageAxes,'YLim'));
setPositionConstraintFcn(handles.scale_tool_h,fcn);
set(zoom(handles.ImageAxes),'ActionPostCallback',@(x,y) ZoomCallbackFcn(handles.ImageAxes));
handles.scale_tool = 'Line';
addNewPositionCallback(handles.scale_tool_h,@(pos) update_scale(handles));
handles = update_scale(handles);
wait(handles.scale_tool_h);
delete(handles.scale_tool_h);
try
guidata(handles.figure1,handles);
catch
end
function ScaleField_Callback(hObject, eventdata, handles)
% hObject    handle to ScaleField (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

handles = update_scale(handles);
guidata(handles.figure1,handles);

% Hints: get(hObject,'String') returns contents of ScaleField as text
%        str2double(get(hObject,'String')) returns contents of ScaleField as a double


% --- Executes during object creation, after setting all properties.
function ScaleField_CreateFcn(hObject, eventdata, handles)
% hObject    handle to ScaleField (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in ScaleToolClearButton.
function ScaleToolClearButton_Callback(hObject, eventdata, handles)
% hObject    handle to ScaleToolClearButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

if isfield(handles,'scale_tool_h')
    delete(handles.scale_tool_h)
end
guidata(handles.figure1,handles);


% --- Executes on button press in MultiColonyCheckBox.
function MultiColonyCheckBox_Callback(hObject, eventdata, handles)
% hObject    handle to MultiColonyCheckBox (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of MultiColonyCheckBox


handles=update_colony_mask(handles);
guidata(handles.figure1,handles);

% --- Executes on selection change in MultiColonyNumbering.
function MultiColonyNumbering_Callback(hObject, eventdata, handles)
% hObject    handle to MultiColonyNumbering (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns MultiColonyNumbering contents as cell array
%        contents{get(hObject,'Value')} returns selected item from MultiColonyNumbering


contents = cellstr(get(handles.MultiColonyNumbering,'String'));
nummeth = contents{get(handles.MultiColonyNumbering,'Value')} ;
if strcmp(nummeth,'Clockwise')
    handles.CircShiftField.Enable = 'on';
else
    handles.CircShiftField.Enable = 'off';
end
handles=update_colony_mask(handles);
guidata(handles.figure1,handles);


% --- Executes during object creation, after setting all properties.
function MultiColonyNumbering_CreateFcn(hObject, eventdata, handles)
% hObject    handle to MultiColonyNumbering (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

function handles=update_colony_mask(handles)

multi = handles.MultiColonyCheckBox.Value;

if multi
    handles.MultiColonyNumbering.Enable = 'on';
    handles.ColonyLabelsButton.Enable   = 'on';
else
    handles.MultiColonyNumbering.Enable = 'off';
    handles.ColonyLabelsButton.Enable   = 'off';
end

circshift = angle(deg2rad(str2double(handles.CircShiftField.String)));

contents = cellstr(get(handles.MultiColonyNumbering,'String'));
nummeth = contents{get(handles.MultiColonyNumbering,'Value')} ;

roi = shift_roi(handles);
msk = roi(:,:,1)>0;
L = bwlabel(msk);
S = regionprops(msk,'BoundingBox','ConvexImage','Centroid','PixelIdxList');
cent = cat(1,S.Centroid);

    
if ~multi || bweuler(handles.Trck.Masks.roi(:,:,1))<=1
    handles.Trck.Masks.colony = handles.Trck.Masks.roi(:,:,1);
    handles.Trck.set_param('geometry_multi_colony',false);
    handles.Trck.set_param('geometry_colony_labels',{});
    handles.Trck.set_param('geometry_Ncolonies',1);
    N=1;
else
    jnd = min(pdist(cent))/4;
    rcent = jnd*round(cent/jnd);
    handles.Trck.set_param('geometry_multi_colony',true);
    switch nummeth
        case 'Vertical'
            a = 1000*rcent(:,2)+rcent(:,1); 
            newlabels = argsort(a);
        case 'Horizontal'
            a = 1000*rcent(:,1)+rcent(:,2); 
            newlabels = argsort(a);
        case 'Clockwise'
            
            mcent = mean(cent);
            cent1 = cent-repmat(mcent,size(cent,1),1);
            theta = angle(cart2pol(cent1(:,2),cent1(:,1)));
            theta = -theta-circshift;
            newlabels = argsort(theta);
    end
    
    S = S(newlabels);
    cent = cent(newlabels,:);
    for k = 1:numel(S)
        kth_object_idx_list = S(k).PixelIdxList;
        L(kth_object_idx_list) = k;
    end
    
    N = length(unique(L(:)))-1;
    handles.Trck.set_param('geometry_Ncolonies',N);
    for i=1:N
        colony_labels{i}=['C',num2str(i)];
        cmsks(:,:,i) = L==i;
    end
    
    
    if length(colony_labels)>=length(handles.user_colony_labels)
        colony_labels(1:length(handles.user_colony_labels)) =  handles.user_colony_labels;
    else
        colony_labels =  handles.user_colony_labels(1:length(colony_labels));
    end
        
    
    handles.Trck.set_param('geometry_colony_labels',colony_labels);
    handles.Trck.set_param('geometry_multi_colony_numbering',nummeth);
    handles.Trck.set_param('geometry_multi_colony_circ_shift',circshift);
    handles.Trck.Masks.colony = cmsks;
end


try
delete(handles.colony_nums)
catch
end

if multi 
   
    for i=1:N
       
        handles.colony_nums(i) = text(cent(i,1),cent(i,2),num2str(i),'FontSize',30,'FontWeight','bold','Color',[1,0.2,0.2]);
        
    end
    
    
    
end

A = handles.Trck.Masks.roi*255;
if multi
    handles.colony_map_to_save = insertText(A,cent-18,1:N,'TextColor','red','FontSize',72,'BoxOpacity',0);
end

      
% --- Executes during object creation, after setting all properties.
function text8_CreateFcn(hObject, eventdata, handles)
% hObject    handle to text8 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% hObject    handle to CircShiftField (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of CircShiftField as text
%        str2double(get(hObject,'String')) returns contents of CircShiftField as a double


function CircShiftField_Callback(hObject, eventdata, handles)
% hObject    handle to MultiColonyNumbering (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns MultiColonyNumbering contents as cell array
%        contents{get(hObject,'Value')} returns selected item from MultiColonyNumbering

handles=update_colony_mask(handles);
guidata(handles.figure1,handles);


% --- Executes during object creation, after setting all properties.
function CircShiftField_CreateFcn(hObject, eventdata, handles)
% hObject    handle to CircShiftField (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in ExportButton.
function ExportButton_Callback(hObject, eventdata, handles)
% hObject    handle to ExportButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

defPath = '~/.tracking/masks/';
if ~isdir(defPath)
    mkdir(defPath);
end

[FileName,PathName,FilterIndex] = uiputfile('*','Select save location:',[defPath,'mask.mat']);
roimsk = shift_roi(handles);
save([PathName,filesep,FileName],'roimsk');


% --- Executes on button press in ColonyLabelsButton.
function ColonyLabelsButton_Callback(hObject, eventdata, handles)
% hObject    handle to ColonyLabelsButton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

NC = handles.Trck.Ncolonies;
prompt = arrayfun(@(x) ['Colony ',num2str(x),':'],1:NC,'UniformOutput',false);
title = 'Colony labels';
dims = 1;
definput = handles.user_colony_labels;

if length(definput)>NC
    definput = definput(1:NC);
elseif length(definput)<NC
    definput(end+1:NC)=handles.Trck.colony_labels(length(definput)+1:NC);
end
    
handles.user_colony_labels(1:NC) = inputdlg(prompt,title,dims,definput);
guidata(handles.figure1,handles);
