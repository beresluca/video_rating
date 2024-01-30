function segment_audio(inputDir, pairs, segFile)
%% Helper function to segment the combined audio files into parts
%
% The boundaries for segmentation are the same as those for the video
% segmentation.
%
% Mandatory inputs:
% inputDir   - Char array, path to folder holding audio data. Combined wav
%              files should be under subdirs "pairPAIRNO".
% pairs      - Numeric value or array, pair numbers, between 1:999.
%
% Optional input:
% segFile    - Char array, path to text file with segmentation info.
%            Defaults to "segmentation_points_5parts.txt".
%
% The function looks for the combined audio following the naming
% convention:
% pairPAIRNO_SESSION_combined_audio_paddedd300.wav,
% where SESSION is always "freeConv" for now, other sessions are not
% supported.
%


%% Input checks

if ~ismember(nargin, 2:3)
    error('Input args "inputDir" and "pairs" are required while "segFile" is optional!');
end
if nargin == 2
    segFile = 'segmentation_points_5parts.txt';
end
if ~exist(inputDir, 'dir')
    error('Input arg "inputDir" should be a valid path!');
end
if ~isvector(pairs)
    error('Input arg "pairs" should be a numeric array!');
end
if ~all(ismember(pairs, 1:999))
    error('Input arg "pairs" should have values between 1:999!');
end

if ~exist(segFile, 'file')
    error('Input arg "segFile" should be a valid file path!');
end

disp([char(10), 'Called segment_audio with input args:',...
    char(10), 'Input dir: ', inputDir, ...
    char(10), 'Pairs: ', num2str(pairs), ...
    char(10), 'Segmentation file: ', segFile]);


%% Read in segmentation file

[line, start1, start2, start3, end1, end2, end3] = textread(segFile, '%2d%2d:%2d:%2d%2d:%2d:%2d');
segmentNo = length(line);
starts = start1*3600 + start2*60 + start3;
endings = end1*3600 + end2*60 + end3;

disp('Segment start and end times (s):');
disp(starts);
disp(endings);


%% Loop through pairs, segment!

for p = 1:length(pairs)
    
    disp([char(10), 'Working on pair ', num2str(p)]); 
    
    pairNo = pairs(p);

    wavfile = fullfile(inputDir, ['pair', num2str(pairNo)], ['pair', num2str(pairNo), '_freeConv_combined_audio_padded300.wav']);
    
    % Exceptions come here!
    if pairNo == 78
        segmentNo = 4;
        starts = starts(1:4);
        endings = endings(1:4);   
    end    
    
    % Define segment file names
    outFiles = cell(segmentNo, 1);
    for s = 1:segmentNo
        outFiles{s} = fullfile(inputDir, ['pair', num2str(pairNo)], ['pair', num2str(pairNo), '_freeConv_combined_audio_padded300_seg', num2str(s), '.wav']);
    end

    % Load audio
    [data, fs] = audioread(wavfile);

    % Write out segments
    for s = 1:segmentNo

        if s ~= segmentNo
            tmp = data(starts(s)*fs+1 : endings(s)*fs, :);
        elseif s == segmentNo
            tmp = data(starts(s)*fs+1 : end, :);
        end

        audiowrite(outFiles{s}, tmp, fs);

    end

    disp('Segments have been written to:');
    disp(outFiles);
    
end
    

