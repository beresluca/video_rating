function combine_audio(inputDir, pairNo, silentTime)
%% Function to combine the audio channels for the video rater task
%
% USAGE: combine_audio(inputDir, pairNo, silentTime=0)
%
% For the video rater task, the two audio and video channels from the free
% conversation task are combined together for playback, this function
% handles the audio combination part. Preprocessed recordings are
% combined into one stereo channel, and are also temporally aligned with
% the video task. Alignment is according to the timestamps defined in the
% combine_video.py outputs. VIDEO COMBINATION COMES FIRST!
% 
% Any audio recording problem should have been mitigated already before
% this function is called. That is, the function audioRepair.m (through
% audioRepairWrapper.m) in the commgame_transcripts repo has alread been
% used to preprocess the raw audio recordings, and its output files (e.g.
% pair99_Mordor_freeConv_repaired_mono.wav) are already available.
% These files have already been aligned to the common start time
% (sharedStartTime var in experiment scripts).
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
if silentTime < 0 || silentTime > 2
    error('Unrealistic padding, probably a mistake! Keep it between 0 and 2 seconds!');
end

disp([char(10), 'Called combineAudioRaterTask with input args:',...
    char(10), 'Input dir: ', inputDir, ...
    char(10), 'Pair number: ', num2str(pairNo), ...
    char(10), 'Padding with silence: ', num2str(silentTime * 1000), ' ms']);


%% Hardcoded params

% expected sampling freq
mordorSrExpect = 44100;
gondorSrExpect = mordorSrExpect;
outputSr = mordorSrExpect;

% allowed deviation from nominal sampling frequency, in Hz
samplingTol = 0.01;


%% Find pair-specific -mat and .wav files

% audio wavs
tmpwav = dir(fullfile(inputDir, ['**/pair', num2str(pairNo), '_Mordor_freeConv_repaired_mono.wav']));
mordorWav = fullfile(tmpwav(1).folder, tmpwav(1).name);
tmpwav = dir(fullfile(inputDir, ['**/pair', num2str(pairNo), '_Gondor_freeConv_repaired_mono.wav']));
gondorWav = fullfile(tmpwav(1).folder, tmpwav(1).name);

% video timestamps
tmpmat = dir([inputDir, '**/pair', num2str(pairNo), '_freeConv_combined_video_start.mat']);
videoTimestampsMat = fullfile(tmpmat(1).folder, tmpmat(1).name);

disp('Found relevant files:');
disp(mordorWav);
disp(gondorWav);
disp(videoTimestampsMat);


%% Load audio and video timestamps

[audioMordor, mordorSr] = audioread(mordorWav);
[audioGondor, gondorSr] = audioread(gondorWav);

if abs(mordorSr - mordorSrExpect) >= samplingTol
    error(['Unexpected sampling rate (', num2str(mordorSr), ' Hz) in Mordor audio at ', mordorWav]);
end
if abs(gondorSr - gondorSrExpect) >= samplingTol
    error(['Unexpected sampling rate (', num2str(gondorSr), ' Hz) in Gondor audio at ', gondorWav]);
end

videoTimestamps = load(videoTimestampsMat);
videoStartDelayFrames = round(videoTimestamps.rel_start * mordorSr);


%% Edit audio to video start, trim to shorter if necessary

audioMordorTrimmed = audioMordor(videoStartDelayFrames:end, 1);
audioGondorTrimmed = audioGondor(videoStartDelayFrames:end, 1);

if length(audioMordorTrimmed) ~= length(audioGondorTrimmed)
    minLength = min(length(audioMordorTrimmed), length(audioGondorTrimmed));
    audioMordorTrimmed = audioMordorTrimmed(1:minLength, 1);
    audioGondorTrimmed = audioGondorTrimmed(1:minLength, 1);
end


%% Combine and save audio
combinedAudio = [audioMordorTrimmed, audioGondorTrimmed];

% ADD SILENCE TO THE BEGINNING
if silentTime ~= 0
    silence = zeros(round(outputSr*silentTime), 2);
    audioWithSilence = [silence; combinedAudio];
    disp(['Combined audio padded with ', num2str(silentTime), ' seconds of silence']);
else
    audioWithSilence = combinedAudio;
end

% output path for edited / synced / corrected audio
outputAudioF = fullfile(inputDir, ['pair', num2str(pairNo), '_freeConv_combined_audio_padded', num2str(silentTime*1000), '.wav']);

audiowrite(outputAudioF, audioWithSilence, outputSr);
disp('Combined audio saved out to:');
disp(outputAudioF);


return
