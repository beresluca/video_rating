function RaterTaskPlayback_v2(inputDir, pairNo)
  %% Video and audio playback script for the rater task.
  %
  % USAGE: RaterTaskPlayback(inputDir, pairNo)
  %
  % Uses the material from the free conversation task. 
  % Includes evaluation of predictability with a slider.
  %
  % Notes:
  % - Slider position is defined relative to the screen size 
  % - Exits after video is done playing or max timeout is reached (vidLength) or 
  %   if you press ESC
  % 
  % Inputs:
  % inputDir  - Char array, path to folder containing relevant audio and video files.
  % pairNo    - Numeric value, pair number, one of 1:999.
  %
  % Outputs:
  % Video display and audio playback related params are saved out into a .mat file
  % at pair99_subjtimes.mat
  %
  % Rater behavioral data (slider position) are save out into a .mat file at
  % pair99Gondor_sliderPosition.mat 
  %
  
  
  
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  %%%%%%% Input checks %%%%%%%%%%%%%%%%%%%%%%%
  
  if nargin ~= 2
    error('Input args "inputDir" and "pairNo" are required!');
  end
  if ~exist(inputDir, 'dir')
    error('Input arg "inputDir" should be a valid path!');
  end
  if ~ismember(pairNo, 1:999)
    error('Input arg "pairNo" should be in range 1:999!');
  end
  
  
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  %%%%%%%% Get user monogram %%%%%%%%%%%%%%%%%
  
  userName = input(['Gépeld be a monogrammodat!', char(10)], 's');
  if length(userName) > 4
    error('Túl hosszú monogramm!');
  end
  
  
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  %%% Screen / vid / audio / task params %%%%%
  
  % screen
  backgrColor = [0 0 0];  % black background
  offbackgrColor = [0 0 0 0];  % black transparent background 
  windowTextSize = 24;  % general text size
  txtColor = [255, 255, 255];  % white letters
  windowSize = [0 0 1920 1080];
  
  % instructions, slider, task
  instruction1 = ['Most le fogunk játszani számodra egy beszélgetést.' char(10),...
  'A feladatod az lesz, hogy egy csúszka segítségével folyamatosan jelezd, ' char(10),...
  'hogy az adott pillanatban mennyire lehetett meglepő az éppen hallgató személynek,' char(10),...
  'amit a másik mondott.', char(10),...
  char(10), 'A skálán az "Egyáltalán nem meglepő" és a "Nagyon meglepő" ' char(10),...
  'értékek között tudsz mozogni az egérrel.'];
  instruction2 = ['Kérlek próbáld ki a csúszka használatát! ' char(10),...
  char(10), 'Ha felkészültél, vidd az egeret a skála bal végéhez, ',...
  'ezután egy bal klikkel indíthatod a feladatot.'];          
  breakMessage1 = ['A részlet végére értünk.', char(10),...
  'Most az előző részhez tartozó kérdőív következik.'];    
  breakMessage2 = ['A következő részhez a SPACE billentyűvel ugorhatsz.'];
  
  instrTime = 2;
  tutorialTimeout = 600; % timeout for tutorial part 
  question      = 'Mennyire meglepő?';
  anchors       = {'Egyáltalán nem meglepő', 'Nagyon meglepő'};
  center        = round(windowSize(3)/2);
  lineLength    = 10; % length of the scale
  width         = 3; % width of scale
  sliderwidth   = 5; 
  scalaLength   = 0.8; % length of scale relative to window size
  scalaPosition = 0.9; % scale position relative to screen (0 is top, 1 is bottom)
  sliderColor   = [255 255 255]; % red(ish)
  scaleColor    = [255 255 255];
  startPosition = 'left'; % position of scale
  displayPos    = false; % display numeric position of slider (0-100)
  
  % audio
  mode = []; % default mode, only playback
  reqLatencyClass = 1;  % not aiming for very low latency
  freq = 44100;  % sampling rate in Hz
  % use MAYA sound card if available, default to system default otherwise
  devName = 'MAYA22 USB'; 
  tmpDevices = PsychPortAudio('GetDevices');
  audiodevice = [];  
  for i = 1:numel(tmpDevices)
    if strncmp(tmpDevices(i).DeviceName, devName, length(devName))
      audiodevice = tmpDevices(i).DeviceIndex;
    end  % if
  end  % for
  
  
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  %%%%% Check audio and video files %%%%%%%%%%
  %%%%% Prepare output files        %%%%%%%%%%
  
  % number of expected segments
  segmentNo = 5;
  % define the audio and video files for each segment,
  % check if they exist
  vidFiles = cell(segmentNo, 1);
  audioFiles = cell(segmentNo, 1);
  for i = 1:segmentNo
    moviename = ['pair', num2str(pairNo), '_freeConv_combined_video_seg', num2str(i), '.mp4'];
    vidFiles{i} = fullfile(inputDir, moviename);
    audiofile = ['pair', num2str(pairNo), '_freeConv_combined_audio_padded300_seg', num2str(i), '.wav'];
    audioFiles{i} = fullfile(inputDir, audiofile); 
    % check the path
    if ~exist(vidFiles{i}, 'file')
      error(['Missing file: ', vidFiles{i}]);
    end
    if ~exist(audioFiles{i}, 'file')
      error(['Missing file: ', vidFiles{i}]);
    end  
  end
  
  
  % prepare output files as well
  sliderValueFile = fullfile(inputDir, ['/pair', num2str(pairNo), '_sliderPosition_', userName, '.mat']);
  timestampsFile = fullfile(inputDir, ['/pair', num2str(pairNo), '_subjTimes_', userName, '.mat']);
  pair_surveyFile = fullfile(inputDir, ['/pair', num2str(pairNo), '_survey_', userName, '_pair.mat']);
  indiv_surveyFile = fullfile(inputDir, ['/pair', num2str(pairNo), '_survey_', userName, '_indiv.mat']);
  
  sliderFiles = cell(segmentNo, 1);
  timestampsFiles = cell(segmentNo, 1);
  survey_Files = cell(segmentNo, 1);
##  for i = 1:segmentNo
##    sliderFiles{i} = fullfile(inputDir, ['/pair', num2str(pairNo), '_sliderPosition_', userName, '_seg', num2str(segmentNo), '.mat']);
##    timestampsFiles{i} = fullfile(inputDir, ['/pair', num2str(pairNo), '_subjTimes_', userName, '_seg', num2str(segmentNo), '.mat']);
##    surveyFiles{i} = fullfile(inputDir, ['/pair', num2str(pairNo), '_survey_', userName, '_seg', num2str(segmentNo), '.mat']);
##  end
##  
  
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  %%%%%%% Psychtoolbox initializations %%%%%%%
  
  PsychDefaultSetup(1);
  InitializePsychSound;
  Screen('Preference', 'Verbosity', 3);
  screen=max(Screen('Screens'));
  RestrictKeysForKbCheck([KbName('ESCAPE'), KbName('space')]);  % only report ESCape key press via KbCheck
  GetSecs; WaitSecs(0.1); KbCheck(); % dummy calls
  
  
  try
    
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%% Get slider scale params from screen %%%%%%%%%%%%  
    
    % Init an openwindow in top-left corner, skip tests
    oldsynclevel = Screen('Preference', 'SkipSyncTests', 1);
    [win, rect] = Screen('OpenWindow', screen, backgrColor, windowSize);
    Screen('TextSize', win, windowTextSize);       
    HideCursor(win);
    
    % Parsing size of the global screen
    globalRect = Screen('Rect', screen);
    
    %% Coordinates of scale lines and text bounds
    if strcmp(startPosition, 'right')
      x = globalRect(3)*scalaLength;
    elseif strcmp(startPosition, 'center')
      x = globalRect(3)/2;
    elseif strcmp(startPosition, 'left')
      x = globalRect(3)*(1-scalaLength);
    else
      error('Only right, center and left are possible start positions');
    end
    
    SetMouse(round(x), round(rect(4)*scalaPosition), win);
    
    leftTick   = [rect(3)*(1-scalaLength) rect(4)*scalaPosition - lineLength rect(3)*(1-scalaLength) rect(4)*scalaPosition  + lineLength];
    rightTick  = [rect(3)*scalaLength rect(4)*scalaPosition - lineLength rect(3)*scalaLength rect(4)*scalaPosition  + lineLength];
    horzLine   = [rect(3)*scalaLength rect(4)*scalaPosition rect(3)*(1-scalaLength) rect(4)*scalaPosition];
    if length(anchors) == 2
      textBounds = [Screen('TextBounds', win, sprintf(anchors{1})); Screen('TextBounds', win, sprintf(anchors{2}))];
    else
      textBounds = [Screen('TextBounds', win, sprintf(anchors{1})); Screen('TextBounds', win, sprintf(anchors{3}))];
    end
    
    % Calculate the range of the scale, which will be needed to calculate the
    % position
    scaleRange = round(rect(3)*(1-scalaLength)):round(rect(3)*scalaLength); % Calculates the range of the scale 
    
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%% Draw first instruction %%%%%%%%%%%%%%%%%%%%%%%%
    
    % display instruction for given time 
    DrawFormattedText(win, instruction1, 'center', 'center', txtColor, [], [], [], 1.5);
    Screen('Flip', win);
    WaitSecs(instrTime);    
    
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%% First while loop for Tutorial             %%%%%%%%%%
    %%%%% Drawing just the scale and an instruction %%%%%%%%%%
    
    % helper variable for the display loop
    clickFlag = false;
    
    offwin = Screen('OpenOffscreenWindow', win, offbackgrColor, windowSize);
    DrawFormattedText(offwin, instruction2, 'center', 'center', txtColor);
    % Drawing the question as text
    DrawFormattedText(offwin, question, 'center', rect(4)*(scalaPosition - 0.03), txtColor);    
    % Drawing the anchors of the scale as text   
    DrawFormattedText(offwin, anchors{1}, leftTick(1, 1) - textBounds(1, 3)/2,  rect(4)*scalaPosition+40); % Left point
    DrawFormattedText(offwin, anchors{2}, rightTick(1, 1) - textBounds(2, 3)/2,  rect(4)*scalaPosition+40); % Right point  
    % Drawing the scale
    Screen('DrawLine', offwin, scaleColor, leftTick(1), leftTick(2), leftTick(3), leftTick(4), width);     % Left tick
    Screen('DrawLine', offwin, scaleColor, rightTick(1), rightTick(2), rightTick(3), rightTick(4), width); % Right tick
    Screen('DrawLine', offwin, scaleColor, horzLine(1), horzLine(2), horzLine(3), horzLine(4), width);     % Horizontal line 
    
    disp([char(10), 'Starting tutorial..', char(10)]);
    
    % while loop for Tutorial with slider
    startTut = GetSecs; 
    while ~KbCheck && GetSecs < startTut+tutorialTimeout && clickFlag==false  
      
      Screen('DrawTextures', win, offwin);  % Draw textures from both windows            
      
      % Parse user input for x location
      [x,~,buttons] = GetMouse(win);  
      
      % Stop at upper and lower bound
      if x > rect(3)*scalaLength
        x = rect(3)*scalaLength;
      elseif x < rect(3)*(1-scalaLength)
        x = rect(3)*(1-scalaLength);
      end
      
      % The slider
      Screen('DrawLine', win, sliderColor, x, rect(4)*scalaPosition - lineLength, x, rect(4)*scalaPosition  + lineLength, sliderwidth);
      
      % Caculates position
      if x <= (min(scaleRange))
        position = 0;
      else
        position = round((x)-min(scaleRange)); % Calculates the deviation from 0. 
        position = (position/(max(scaleRange)-min(scaleRange)))*100; % Converts the value to percentage               
      end          
      
      % Display position
      if displayPos
        DrawFormattedText(win, num2str(round(position)), 'center', rect(4)*(scalaPosition - 0.07));             
      end              
      
      % check if there was a button press
      if any(buttons)
        clickFlag = true;        
        % wait till button is released (click ended)
        while any(buttons)
          WaitSecs(0.01);  % 10 msecs
          [~, ~, buttons] = GetMouse(win);
        end  
      end   
      
      Screen('Flip', win);  % Show new texture   
      
    end  % while
    
    disp([char(10) 'Tutorial finished, moving on..']);     
    WaitSecs(1); 
    
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%   LOOP OVER SEGMENTS   %%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%    
    
    for segmentIdx = 1:segmentNo
      
      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
      %%%%%%%%%% Open audio device, prepare playback %%%%%%%%%%%   
      
      [y, freq] = psychwavread(audioFiles{segmentIdx});
      wavedata = y';
      nrchannels = size(wavedata,1); % Number of rows == number of channels. 
      
      if segmentIdx == 1
        pahandle = PsychPortAudio('Open', audiodevice, mode, reqLatencyClass, freq, nrchannels);
      end
      
      % Fill the audio playback buffer with the audio data 'wavedata':
      PsychPortAudio('FillBuffer', pahandle, wavedata);
      disp([char(10), 'Audio ready for playback']);   
      
      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
      %%%%%%%%%%%%%% Loading the video file  %%%%%%%%%%%%%%%%%%%
      
      [moviePtr, duration, fps, moviewidth, movieheight, framecount] = Screen('OpenMovie', win, vidFiles{segmentIdx});
      disp(['Movie ' vidFiles{segmentIdx}, ' opened and ready to play! ',...
      char(10), 'Duration: ', num2str(duration), 'secs, with ', num2str(framecount), ' frames.']);
      
      % preallocate variables for timestamps and mouse position output,
      % based on the frame count of movie
      sliderPos = nan(framecount + 1000, 1);
      flipTimes = nan(framecount + 1000, 1);
      texTimestamps = nan(framecount + 1000, 1);
      audioData = nan(framecount + 1000, 4);
      
      
      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
      %%%%%%%%%%%%%%% Playing audio + video %%%%%%%%%%%%%%%%%%%% 
      
      disp([char(10) 'Starting movie + sound...' char(10)]);
      droppedFrames = Screen('PlayMovie', moviePtr, 1);
      startAt = GetSecs;
      audioRealStart = PsychPortAudio('Start', pahandle, 1); % start playing audio immediately
      % get current status of audio: includes real start of playback(?)
      audioStartStatus = PsychPortAudio('GetStatus', pahandle); 
      disp(audioStartStatus);
      
      % helper variables for the display loop
      tex = 0;
      count = 0;
      
      
      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%   
      %%%% Main while loop for slider during audio + video %%%%% 
      
      while true
        
        % check keyboard
        [keyIsDown, ~, keyCode] = KbCheck;
        
        % if ESC was pressed, break out of while loop (finish task)
        if keyIsDown && keyCode(KbName('ESCAPE'))
          break;
          
          % if SPACE was pressed, pause audio + video, start again at next press
        elseif keyIsDown && keyCode(KbName('space'))
          PsychPortAudio('Stop', pahandle);
          Screen('PlayMovie', moviePtr, 0);
          KbReleaseWait;
          while true
            [keyIsDown, ~, keyCode] = KbCheck;
            if keyIsDown && keyCode(KbName('space'))
              Screen('PlayMovie', moviePtr, 1);
              PsychPortAudio('Start', pahandle, [], [], [], [], 1);
              KbReleaseWait;
              break;
            end
          end
          
        end  % if keyIsDown && keyCode
        
        % Get next frame from video
        [tex, textime] = Screen('GetMovieImage', win, moviePtr, 1);
        % If there is no next frame, the video has ended, break out of while 
        % loop (finish task)
        if tex < 0
          break;
        end
        
        % Draw new frame 
        Screen('DrawTexture', win, tex);
        
        txtColor = [255 255 255];
        % Drawing the question as text
        DrawFormattedText(win, question, 'center', rect(4)*(scalaPosition - 0.03), txtColor); 
        % Drawing the anchors of the scale as text
        if length(anchors) == 2
          % Only left and right anchors
          DrawFormattedText(win, anchors{1}, leftTick(1, 1) - textBounds(1, 3)/2,  rect(4)*scalaPosition+40); % Left point
          DrawFormattedText(win, anchors{2}, rightTick(1, 1) - textBounds(2, 3)/2,  rect(4)*scalaPosition+40); % Right point          
        end
        % Drawing the scale
        Screen('DrawLine', win, scaleColor, leftTick(1), leftTick(2), leftTick(3), leftTick(4), width);     % Left tick
        Screen('DrawLine', win, scaleColor, rightTick(1), rightTick(2), rightTick(3), rightTick(4), width); % Right tick
        Screen('DrawLine', win, scaleColor, horzLine(1), horzLine(2), horzLine(3), horzLine(4), width);     % Horizontal line      
        
        % Parse user input for x location
        [x, ~, buttons] = GetMouse(win);  
        
        % Stop at upper and lower bound
        if x > rect(3)*scalaLength
          x = rect(3)*scalaLength;
        elseif x < rect(3)*(1-scalaLength)
          x = rect(3)*(1-scalaLength);
        end
        
        % Draw the slider
        Screen('DrawLine', win, sliderColor, x, rect(4)*scalaPosition - lineLength, x, rect(4)*scalaPosition  + lineLength, sliderwidth);
        
        % Caculate position
        if x <= (min(scaleRange))
          position = 0;
        else
          position = (round((x)-min(scaleRange))); % Calculates the deviation from 0. 
          position = (position/(max(scaleRange)-min(scaleRange)))*100; % Converts the value to percentage               
        end   
        
        % Display position
        if displayPos
          DrawFormattedText(win, num2str(round(position)), 'center', rect(4)*(scalaPosition - 0.07));             
        end           
        
        % Flip
        fliptime = Screen('Flip', win);
        Screen('Close', tex); % Release texture
        % Adjust frame counter      
        count = count + 1;  % counter for movie image     
        
        % Get audio status
        s = PsychPortAudio('GetStatus', pahandle);   
        
        % Store interesting stuff
        audioData(count, :) = [s.StartTime, s.CurrentStreamTime, s.ElapsedOutSamples, s.XRuns];
        texTimestamps(count, 1) = textime; % store timestamps of when textures become available    
        flipTimes(count, 1) = fliptime; % store timestamps of flips       
        sliderPos(count, 1) = round(position); % store mouse position data   
        
        
      end  % while
      
      
      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%   
      %%%%%%%%%% Break between segments %%%%%%%%%%%%%%%%%%%%%%%% 
      
      audioEndStatus = PsychPortAudio('GetStatus', pahandle); 
      PsychPortAudio('Stop', pahandle);
      Screen('CloseMovie');
      disp([char(10), char(10), '  Segment ended!']);
      
      txtColor = [255 255 255];
      % Break message between segments
      DrawFormattedText(win, breakMessage1, 'center', 'center', txtColor, [], [], [], 1.5);
      breakMessageStart = Screen('Flip', win);
      WaitSecs(3);
      
      % Saving important variables
      % Strip nans from array ends
      texTimestamps(count+1:end, :) = [];
      flipTimes(count+1:end, :) = [];
      sliderPos(count+1:end, :) = [];
      audioData(count+1:end, :) = [];
      
      
      %%%%%%%%%%%%%%%%%%%%%%% Survey part %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
      
      % construct output mat files for the surveys
      sliderFiles{segmentIdx} = fullfile(inputDir, ['/pair', num2str(pairNo), '_sliderPosition_', userName, '_seg', num2str(segmentIdx), '.mat']);
      timestampsFiles{segmentIdx} = fullfile(inputDir, ['/pair', num2str(pairNo), '_subjTimes_', userName, '_seg', num2str(segmentIdx), '.mat']);
      surveyFiles{segmentIdx} = fullfile(inputDir, ['/pair', num2str(pairNo), '_survey_', userName, '_seg', num2str(segmentIdx), '.mat']);
      
      % save important variables from the slider 
      save(sliderFiles{segmentIdx}, 'sliderPos', '-v7');  
      save(timestampsFiles{segmentIdx}, 'flipTimes', 'audioRealStart', 'audioStartStatus',... 
      'audioEndStatus', 'audioData', 'texTimestamps', 'startAt', '-v7');
      
      % Launch survey (will initialize a new window and then close it)
      selects = survey_mouse(pairNo, "segment_eval", userName);
      save(surveyFiles{segmentIdx}, 'selects', '-v7');
      
      % need to change back to white text color for the slider
      txtColor = [255 255 255];
      
      % Break message between segments
      DrawFormattedText(win, breakMessage2, 'center', 'center', txtColor, [], [], [], 1.5);
      breakMessageStart = Screen('Flip', win);
      
      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
      
      % Wait until key press
      KbReleaseWait;
      while true
        % check keyboard
        [keyIsDown, ~, keyCode] = KbCheck;
        % if SPACE was pressed, break out of while loop (go on with task)
        if keyIsDown && keyCode(KbName('space'))
          break;
        end
      end  % while 
      
      WaitSecs(1);
      
    end  % for segmentIdx
    
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%% Close audio + video, save data %%%%%%%%%%%%%%%%     
    
    audioEndStatus = PsychPortAudio('GetStatus', pahandle); 
    PsychPortAudio('Stop', pahandle);
    Screen('CloseMovie');
    disp([char(10), char(10), '  Movie ended, bye!']);
    
    % Saving important variables
    % Strip nans from array ends
    texTimestamps(count+1:end, :) = [];
    flipTimes(count+1:end, :) = [];
    sliderPos(count+1:end, :) = [];
    audioData(count+1:end, :) = [];
    % save
    save(sliderValueFile, 'sliderPos', '-v7');  
    save(timestampsFile, 'flipTimes', 'audioRealStart', 'audioStartStatus',... 
    'audioEndStatus', 'audioData', 'texTimestamps', 'startAt', '-v7');
    
    % launch surveys at the end of the video
    selects = survey_mouse(pairNo, "pair_eval", userName);
    save(pair_surveyFile, 'selects', '-v7');
    selects = survey_mouse(pairNo, "individual_eval", userName);
    save(indiv_surveyFile, 'selects', '-v7');
    
    %%% Cleaning up 
    Screen('CloseAll');
    PsychPortAudio('Close');
    RestrictKeysForKbCheck([]);
    sca;
    
    
  catch ME
    sca; 
    rethrow(ME);
    
  end %try
  
  
endfunction
