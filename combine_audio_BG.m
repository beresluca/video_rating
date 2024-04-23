
%% Hardcoded params
inputDir = '/media/lucab/data_hdd/';
silentTime = 0.3;
pairNo = 169;
session = 'BG1';

% expected sampling freq
mordorSrExpect = 44100;
gondorSrExpect = mordorSrExpect;
outputSr = mordorSrExpect;

% allowed deviation from nominal sampling frequency, in Hz
samplingTol = 0.01;


%% Find pair-specific -mat and .wav files

% audio wavs
tmpwav = dir(fullfile(inputDir, ['**/pair', num2str(pairNo), '_Mordor_', session, '_repaired_mono_noisered.wav']));
mordorWav = fullfile(tmpwav(1).folder, tmpwav(1).name);
tmpwav = dir(fullfile(inputDir, ['**/pair', num2str(pairNo), '_Gondor_', session, '_repaired_mono_noisered.wav']));
gondorWav = fullfile(tmpwav(1).folder, tmpwav(1).name);

% video timestamps
%tmpmat = dir([inputDir, '**/pair', num2str(pairNo), '_', 'Mordor_', session, '_times.mat']);
tmpmat = dir([inputDir, '**/pair', num2str(pairNo), '_', session, '_combined_video_start.mat']);
videoTimestampsMat = fullfile(tmpmat(1).folder, tmpmat(1).name);
%videoTimestampsMat = '/media/lucab/data_hdd/lucab_old/pupildata_CommGame/pair72/pair72_Mordor/pair72_Mordor_behav/pair72_Mordor_BG2_times.mat';

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
combinedAudio = [audioMordor, audioGondor];

% ADD SILENCE TO THE BEGINNING
if silentTime ~= 0
    silence = zeros(round(outputSr*silentTime), 2);
    audioWithSilence = [silence; combinedAudio];
    disp(['Combined audio padded with ', num2str(silentTime), ' seconds of silence']);
else
    audioWithSilence = combinedAudio;
end

% output path for edited / synced / corrected audio
outputAudioF = fullfile(inputDir, ['pair', num2str(pairNo), '_', session, '_combined_audio_padded', num2str(silentTime*1000), '.wav']);

audiowrite(outputAudioF, audioWithSilence, outputSr);
disp('Combined audio saved out to:');
disp(outputAudioF);

