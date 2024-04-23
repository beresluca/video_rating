function play_BG_videos(pairNo, session_id)

  addpath(genpath('/home/lucab/Documents/video_rating/..'));

  inputDir = '/media/lucab/data_hdd/';
  ##pairNo = 123;
  ##session_id = 'BG1';

  % screen parameters 
  backgrColor = [0 0 0];  % black background
  windowSize = [0 0 1920 1080];

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

  % movie
  #moviename = ['pair', num2str(pairNo), '_', session_id, '_pupil_combined_video.mp4'];
  moviename = ['pair', num2str(pairNo), '_', session_id, '_combined_video.mp4'];
  vidFile = fullfile(inputDir, moviename);
  audio_name = ['pair', num2str(pairNo), '_', session_id, '_combined_audio_padded300.wav'];
  audioFile = fullfile(inputDir, audio_name); 
  % check the path
  if ~exist(vidFile, 'file')
    error(['Missing file: ', vidFile]);
  end
  if ~exist(audioFile, 'file')
    error(['Missing file: ', audioFile]);
  end  


  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  %%%%%%% Psychtoolbox initializations %%%%%%%
  PsychDefaultSetup(1);
  InitializePsychSound;
  Screen('Preference', 'Verbosity', 3);
  screen=max(Screen('Screens'));
  RestrictKeysForKbCheck([KbName('ESCAPE'), KbName('space'), KbName('q'), KbName('RightArrow')]); 
  GetSecs; WaitSecs(0.1); KbCheck(); % dummy calls
    
  % Init an openwindow, skip tests
  oldsynclevel = Screen('Preference', 'SkipSyncTests', 1);
  [win, winRect] = Screen('OpenWindow', screen, backgrColor, windowSize);     
  HideCursor(win);
    
  try
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%% Open audio device, prepare playback %%%%%%%%%%%   
    
    [y, freq] = psychwavread(audioFile);
    wavedata = y';
    nrchannels = size(wavedata,1); % Number of rows == number of channels. 
    
    pahandle = PsychPortAudio('Open', audiodevice, mode, reqLatencyClass, freq, nrchannels);

    % Fill the audio playback buffer with the audio data 'wavedata':
    PsychPortAudio('FillBuffer', pahandle, wavedata);
    disp([char(10), 'Audio ready for playback']);   
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%% Loading the video file  %%%%%%%%%%%%%%%%%%%
    
    [moviePtr, duration, fps, moviewidth, movieheight, framecount] = Screen('OpenMovie', win, vidFile);
    disp(['Movie ' vidFile, ' opened and ready to play! ',...
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
    %disp(audioStartStatus);
    
    % helper variables for the display loop
    tex = 0;
    count = 0;
    
    escFlag = false;
    
    while true
          
      % check keyboard
      [keyIsDown, ~, keyCode] = KbCheck;
      
      % if Q was pressed, abort
      if keyIsDown && keyCode(KbName('q'))
        escflag = true
        disp('User requested abort ...');
        sca;
        PsychPortAudio('Close');
        return;
        
      % Further keyboard checks...
      elseif keyIsDown && keyCode(KbName('RightArrow'))
          % Advance movietime by 10 seconds:
          advance_secs = 10
          %PsychPortAudio('Stop', pahandle);
          Screen('SetMovieTimeIndex', moviePtr, Screen('GetMovieTimeIndex', moviePtr) + advance_secs);
          current_time = GetSecs;
          %PsychPortAudio('Start', pahandle, [], current_time + advance_secs, [], [], 1);
          
        
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
          % if Q was pressed, abort
          elseif keyIsDown && keyCode(KbName('q'))
            escflag = true
            disp('User requested abort ...');
            sca;
            PsychPortAudio('Close');
            return;
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
      
      timeindex = Screen('GetMovieTimeIndex', moviePtr);
      
      txtColor = [255 255 255];
      txtPosition = 0.9;
      % Drawing the question as text
      DrawFormattedText(win, ['Elapsed time: ', num2str(round(timeindex))], 'center', winRect(4)*(txtPosition - 0.03), txtColor); 

      % Flip
      fliptime = Screen('Flip', win);
      Screen('Close', tex); % Release texture
      % Adjust frame counter      
      count = count + 1;  % counter for movie image     
      
      % Get audio status
      s = PsychPortAudio('GetStatus', pahandle);   
      
  ##    % Store interesting stuff
  ##    audioData(count, :) = [s.StartTime, s.CurrentStreamTime, s.ElapsedOutSamples, s.XRuns];
  ##    texTimestamps(count, 1) = textime; % store timestamps of when textures become available    
  ##    flipTimes(count, 1) = fliptime; % store timestamps of flips           
      
    end  % while
    
    %%%%%%%%%% Close audio + video %%%%%%%%%%%%%%%%     
    audioEndStatus = PsychPortAudio('GetStatus', pahandle); 
    PsychPortAudio('Stop', pahandle);
    Screen('CloseMovie');
    disp([char(10), char(10), '  Movie ended, bye!']);
    
    %%% Cleaning up 
    Screen('CloseAll');
    PsychPortAudio('Close');
    RestrictKeysForKbCheck([]);
    sca;
    
  catch ME
    sca; 
    rethrow(ME);
    
  end_try_catch
  
endfunction
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  
  


