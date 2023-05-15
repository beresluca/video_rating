function [ window, windowRect, vbl, ifi ] = prepareScreen( ssize )
%GETSCREEN Get screen ready for dispaly
%   Return screen information for manipulation

%--------------------------------------------------------------------------
%                       Global variables
%--------------------------------------------------------------------------
global black white grey;


if nargin < 1
    ssize = [0 0 1920 1080];
end

% Clear the workspace
%clearvars;
close all;
sca;

% Here we call some default settings for setting up Psychtoolbox
PsychDefaultSetup(1);
oldsynclevel = Screen('Preference', 'SkipSyncTests', 0);

%--------------------------------------------------------------------------
%                       Screen initialization
%--------------------------------------------------------------------------

% Find the screen to use for displaying the stimuli. By using "max" this
% will display on an external monitor if one is connected.
Screen('Preference', 'Verbosity', 3);
screenid = max(Screen('Screens'));

% color
backgrColor = [255 255 255];  % white background
% color
black = BlackIndex(screenid);
white = WhiteIndex(screenid);
grey = white / 2;

% Set up screen
[window, windowRect] = Screen('OpenWindow', screenid, white, ssize);

% Set font
##Screen('TextFont', window, 'Liberation Sans');
##Screen('Textsize', window, 23);
Screen('TextFont', window, 'Liberation Sans');
Screen('Textsize', window, 23);

% Set the blend function
Screen('BlendFunction', window, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

%Screen('Preference','TextEncodingLocale','UTF-8');

% Measure the vertical refresh rate of the monitor
ifi = Screen('GetFlipInterval', window);

% Retreive the maximum priority number and set max priority
topPriorityLevel = MaxPriority(window);
Priority(topPriorityLevel);

% Flip outside of the loop to get a time stamp
vbl = Screen('Flip', window);

end

