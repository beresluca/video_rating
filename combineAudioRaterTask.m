function combineAudioRaterTask(inputDir, pairNo, silentTime)
%% Function to combine the audio channels for the video rater task
%
% USAGE: combineAudioRaterTask(inputDir, pairNo, silentTime=0)
%
% For the video rater task, the two audio and video channels from the free
% conversation task are combined together for display. This function
% handles the audio combination part: the two microphone channels are
% combined into one stereo channel, and are also temporally aligned with
% the video task. Alignment is to the 10th (HARDCODED) video frame of 
% Mordor video.
% 
% 
% Two types of audio recording problems are also mitigated by the function:
%
% (1) When a buffer underflow occured, we see the details of the missing
% portion from the audio status parameters saved out during the task. Such
% missing segments are recovered (injected) as segments filled with silence.
% This behavior is controlled by two HARDCODED params, "timeDiffThr" and 
% "missingSampleThr".
%
% (2) Sampling rates are not fully consistent across different sound cards
% used and might show deviations from nominal sampling rate. Such problems
% are detected and the recorded audio resampled if necessary. The maximum
% tolerated deviation from nominal sampling rate is controlled by the
% HARDCODED variable "samplingTol". 
%
%
%
% Inputs:
% inputDir   - Char array, path to folder holding pair-level data. The
%              folder is searched recursively for the right files.
% pairNo     - Numeric value, pair number, one of 1:99.
% silentTime - Extra padding with silence at the beginning of the combined
%              audio, to account for audio-to-video delay. In seconds. 
%              Defaults to 0.
%
% The output is the edited, synched audio file at:
% inputDir/pair[pairNo]_freeConv_combined_audio_padded[silentTime*1000].wav
%
%
% Notes:
% 
% last edited: 2023.05.
%


%% Input checks

if ~ismember(nargin, 2:3)
    error('Input args inputDir and pairNo are required while silentTime is optional!');
end
if nargin == 2
    silentTime = 0;
end
if ~exist(inputDir, 'dir')
    error('Input arg inputDir should be a valid path!');
end
if ~ismember(pairNo, 1:999)
    error('Input arg pairNo should be one of 1:999!');
end
if silentTime < 0 || silentTime > 5
    error('Unrealistic padding, probably a mistake! Keep it between 0 and 5 seconds!');
end

disp([char(10), 'Called combineAudioRaterTask with input args:',...
    char(10), 'Input dir: ', inputDir, ...
    char(10), 'Pair number: ', num2str(pairNo), ...
    char(10), 'Padding with silence: ', num2str(silentTime * 1000), ' ms']);


%% Hardcoded params

% we ignore the first N video frames due to jitter in first recording
% timestamps
framesIgnore = 10;

% expected sampling freq
fs = 44100;

% threshold for detecting and correcting for harmful underflows in the recordings
timeDiffThr = 0.020; 
missingSampleThr = 225;

% allowed deviation from nominal sampling frequency, in Hz
samplingTol = 0.5;


%% Find pair-specific -mat and .wav files

mordorfiles = struct; gondorfiles = struct; 

% audio wav and mat files for Mordor lab
tmpwav = dir([inputDir, '**/pair', num2str(pairNo), '_Mordor_freeConv_audio.wav']);
tmpmat = dir([inputDir, '**/pair', num2str(pairNo), '_Mordor_freeConv_audio.mat']);
mordorfiles.audiowav = fullfile(tmpwav(1).folder, tmpwav(1).name);
mordorfiles.audiomat = fullfile(tmpmat(1).folder, tmpmat(1).name);

% audio wav and mat files for Gondor lab
tmpwav = dir([inputDir, '**/pair', num2str(pairNo), '_Gondor_freeConv_audio.wav']);
tmpmat = dir([inputDir, '**/pair', num2str(pairNo), '_Gondor_freeConv_audio.mat']);
gondorfiles.audiowav = fullfile(tmpwav(1).folder, tmpwav(1).name);
gondorfiles.audiomat = fullfile(tmpmat(1).folder, tmpmat(1).name);

% video timestamps
tmpmat = dir([inputDir, '**/pair', num2str(pairNo), '_Mordor_freeConv_videoTimes.mat']);
mordorfiles.videomat = fullfile(tmpmat(1).folder, tmpmat(1).name);

disp('Found relevant files:');
disp(mordorfiles);
disp(gondorfiles);


%% Extract all relevant timestamps

% VIDEO
% Get video length based on timestamps of video frame captures.
tmp = load(mordorfiles.videomat);
vidCaptureTimes = tmp.frameCaptTime;
%flipTimes = tmp.flipTimestamps;
% Trim NaNs
vidCaptureTimes(isnan(vidCaptureTimes)) = [];
%flipTimes(isnan(flipTimes)) = [];

% from the frame capture times, the last value is supposed to be zero!
% Get rid of it!
if vidCaptureTimes(end) == 0
    vidCaptureTimes(end) = [];
end

% first frame to take into account is determined by framesIgnore
firstFrameTime = vidCaptureTimes(framesIgnore);
endFrameTime = vidCaptureTimes(end);
vidLength = endFrameTime - firstFrameTime;

% AUDIO
% timestamps of first recorded audio frames
tmp = load(mordorfiles.audiomat);
audioStart.mordor = tmp.perf.firstFrameTiming;
tstats.mordor = tmp.perf.tstats;
tmp = load(gondorfiles.audiomat);
audioStart.gondor = tmp.perf.firstFrameTiming;
tstats.gondor = tmp.perf.tstats;

disp('Extracted relevant timestamps and audio recording metadata');


%% Find underflows in audio channels, based on audio frame timing

% Correct for missing audio packets (occasional underflows) that 
% correspond to jumps in stream timings without audio data 
% First, detect "jumps", that is, audio frames where there is a 
% "large" change in streaming time from frame to frame, while the number of 
% elapsed samples does not match it.

audioRepair = struct;
audioRepair.mordor = [];
audioRepair.gondor = [];
for labIdx = {'mordor', 'gondor'}
    lab = labIdx{:};
    audioTimes = tstats.(lab)(2, :)';
    elapsedSamples = tstats.(lab)(1, :)';
    suspectFrames = find(diff(audioTimes) > timeDiffThr);
    counter = 1;
    % check each suspect audioframe for skipped material
    if ~isempty(suspectFrames)
        
        for i = 1:length(suspectFrames)
            timingDiff = audioTimes(suspectFrames(i)+1) - audioTimes(suspectFrames(i));
            sampleDiff = elapsedSamples(suspectFrames(i)+1) - elapsedSamples(suspectFrames(i));
            expectedSamples = timingDiff*fs;
            if expectedSamples - sampleDiff > missingSampleThr
               audioRepair.(lab)(counter, 1:2) = [suspectFrames(i), expectedSamples-sampleDiff];
               counter = counter + 1;
            end
        end  % for i
        
    end  % if ~isempty 
    
end  % for lab

disp('Checked for missing samples (underflows)');
disp(['For Mordor, there were ', num2str(size(audioRepair.mordor, 1)), ' suspected events']);
disp(['For Gondor, there were ', num2str(size(audioRepair.gondor, 1)), ' suspected events']);


%% Load audio

audioData = struct;
[audioData.mordor, tmp] = audioread(mordorfiles.audiowav); 
if tmp ~= fs
    error(['Unexpected sampling freq (', num2str(tmp), ') in audio file at ', mordorfiles.audiowav ]);
end
[audioData.gondor, tmp] = audioread(gondorfiles.audiowav); 
if tmp ~= fs
    error(['Unexpected sampling freq (', num2str(tmp), ') in audio file at ', gondorfiles.audiowav ]);
end
% sanity check - audio recordings must have started before video stream
if audioStart.mordor >= firstFrameTime || audioStart.gondor >= firstFrameTime
    error("Insane audio versus video stream start times!");
end

disp('Loaded audio files');


%% Repair loaded audio for missing frames (underflows)

for labIdx = {'mordor', 'gondor'}
    lab = labIdx{:};
    
    if ~isempty(audioRepair.(lab))
        elapsedSamples = tstats.(lab)(1, :)';
        
        % for inserting audio samples, do it in reverse order, otherwise 
        % the indices get screwed
        for i = size(audioRepair.(lab), 1):-1:1
            % sample to insert silence at
            startSample = elapsedSamples(audioRepair.(lab)(i, 1) + 1);
            % define silence (zeros)
            silentFrame = zeros(round(audioRepair.(lab)(i, 2)), 2);
            % special rule for inserting silent frames when those would be at the very end, 
            % potentially out of bounds of recorded audio
            if startSample > size(audioData.(lab), 1) + 1
                audioData.(lab) = [audioData.(lab); silentFrame];
            % otherwise we insert silent frames to their expected location
            else
                audioData.(lab) = [audioData.(lab)(1:startSample, 1:2); silentFrame; audioData.(lab)(startSample+1:end, 1:2)];
            end
        end  % for i
        
    end  % if ~isempty
    
end  % for lab

disp('Inserted silent frames for detected underflow events');


%% Estimate real (empirical) sampling frequency 

% MORDOR
% estimate sampling frequency based on the size of the (repaired) audio
% data and the total time elapsed while recording
streamTimesM = tstats.mordor(2, :)';
totalSamplesM =size(audioData.mordor, 1);
totalTimeM = streamTimesM(end)-streamTimesM(1);
fsEmpMordor = totalSamplesM/totalTimeM;
disp(['Estimated sampling frequency for Mordor audio: ',... 
    num2str(fsEmpMordor), ' Hz']);

% GONDOR
streamTimesG = tstats.gondor(2, :)';
totalSamplesG =size(audioData.gondor, 1);
totalTimeG = streamTimesG(end)-streamTimesG(1);
fsEmpGondor = totalSamplesG/totalTimeG;
disp(['Estimated sampling frequency for Gondor audio: ',... 
    num2str(fsEmpGondor), ' Hz']);


%% Resample audio channels, if needed

% MORDOR
if abs(fsEmpMordor - fs) > samplingTol
    tx = 0:1/fsEmpMordor:totalTimeM;
    data = audioData.mordor;
    if numel(tx) ~= size(data, 1)
        tx = tx(1:size(data, 1));
    end
    newFs = fs;
    resampledDataMordor = resample(data, tx, newFs);
    disp(['Resampled Mordor audio to nominal (', num2str(fs),... 
        ' Hz) sampling frequency']);
    audioData.mordor = resampledDataMordor;
end

% GONDOR
if abs(fsEmpGondor - fs) > samplingTol
    tx = 0:1/fsEmpGondor:totalTimeG;
    data = audioData.gondor;
    if numel(tx) ~= size(data, 1)
        tx = tx(1:size(data, 1));
    end
    newFs = fs;
    resampledDataGondor = resample(data, tx, newFs);
    disp(['Resampled Gondor audio to nominal (', num2str(fs),... 
    ' Hz) sampling frequency']);
    audioData.gondor = resampledDataGondor;
end


%% Edit audio to video start:
% Both channels are trimmed so that they start from firstFrameTime
% Since sampling frequency issues are already fixed at this point, we
% assume that sampling frequency = fs, and use that for trimming

% trim from start and end
for labIdx = {'mordor', 'gondor'}
    lab = labIdx{:};
    startDiff = firstFrameTime - audioStart.(lab);
    audioData.(lab) = audioData.(lab)(round(startDiff*fs)+1 : end, :);
    if size(audioData.(lab), 1) > vidLength*fs
        audioData.(lab) = audioData.(lab)(1 : round(vidLength*fs), :);
    elseif size(audioData.(lab), 1) < vidLength*fs
        disp(['! After trimming to video start, ', lab, ' audio is shorter than the video !']);
    end
end
disp('Trimmed both audio channels to video start and end');

% turn to mono and normalize intensity
for labIdx = {'mordor', 'gondor'}
    lab = labIdx{:};
    audioData.(lab) = mean(audioData.(lab), 2);
    audioData.(lab) = (audioData.(lab) / max(audioData.(lab))) * 0.99;
end
disp('Audio channels are set to mono and normalized');

% check length, there might be a difference still
if length(audioData.mordor) ~= length(audioData.gondor)
    lm = length(audioData.mordor);
    lg = length(audioData.gondor);
    if lm < lg
        audioData.gondor = audioData.gondor(1:lm);
    elseif lm > lg
        audioData.mordor = audioData.mordor(1:lg);
    end
    disp('Audio channel length values adjusted (trimmed to the shorter)');
end


%% combine and save audio
combinedAudio = [audioData.mordor, audioData.gondor];

% ADD SILENCE TO THE BEGINNING
if silentTime ~= 0
    silence = zeros(round(fs*silentTime), 2);
    audioWithSilence = [silence; combinedAudio];
    disp(['Combined audio padded with ', num2str(silentTime), ' seconds of silence']);
else
    audioWithSilence = combinedAudio;
end

% output path for edited / synced / corrected audio
outputAudioF = fullfile(inputDir, ['pair', num2str(pairNo), '_freeConv_combined_audio_padded', num2str(silentTime*1000), '.wav']);

audiowrite(outputAudioF, audioWithSilence, fs);
disp('Combined audio saved out to:');
disp(outputAudioF);


return




