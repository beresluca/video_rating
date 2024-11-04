function allRaters

% script to load all raters' data and aggregate them into one 3D array with
% dimensions:
% rater X video X items
% (8 X 13 X 44)
%

raters = {'bo', 'KK', 'TT', 'SAR', 'Sz V', 'PE', 'PSz', 'SJ'};  % 8, full
%raters = {'bo', 'KK', 'TT', 'SAR', 'Sz V', 'PE', 'PSz'};  % 7
%raters = {'KK', 'TT', 'SAR', 'Sz V'};  % 4
raterNo = length(raters);
baseDir = '/media/lucab/data_hdd/rater_task_files/allpairs_16_233/';
vidNo = 167;
itemNo = 44;
allData = nan(raterNo, vidNo, itemNo);

for rIdx = 1:raterNo
    
    matFile = fullfile(baseDir, ['surveys_rater_', raters{rIdx}, '_67_233.mat']);
    
    if exist(matFile, 'file')
        tmp = load(matFile);
        allData(rIdx, :, :) = tmp.surveyData';
    else
        warning(['Could not find mat file for rater ', raters{rIdx}, '!']);
        warning(['File path should have been: ', matFile]);
    end
    
end

saveFile = fullfile('/home/lucab/video_rating_scripts/surveys_raters_all_67_233.mat');
save(saveFile, 'allData', 'raters');
       
