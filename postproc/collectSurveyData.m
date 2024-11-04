function collectSurveyData(rater)

% script to load all survey data from a given rater, for all pairs (videos)

% basic params
videos = 67:233;  % potential videos that have been rated
vidNo = length(videos);
disp(vidNo)
%baseDir = '/media/adamb/data_disk/video_rating';
baseDir = '/media/lucab/data_hdd/rater_task_files/allpairs_16_233/';
surveyTypes = {'seg1', 'seg2', 'seg3', 'seg4', 'seg5', 'pair', 'indiv'};  % potential survey types
surNo = length(surveyTypes);
itemNo = 44;  % number of all items for a given video (5*5 + 9 + 2*5)

disp([char(10), char(10), 'Loading data for rater ', rater]);

% define possible survey files, all of them
surFiles = cell(vidNo, surNo);
for vidIdx = 1:vidNo
    for surIdx = 1:surNo
        surFiles{vidIdx, surIdx} = fullfile(baseDir, ['pair', num2str(videos(vidIdx)), '_survey_', rater, '_', surveyTypes{surIdx}, '.mat']);
    end
end

% check which ones exist
fileCheck = cellfun(@exist, surFiles);
disp(['Existing files for rater ', rater, ', in a matrix of "videos X survey files":']);
disp(fileCheck);

% matrix to hold all survey data for given subject:
surveyData = nan(itemNo, vidNo);  % items X videos
% load all files that exist, collect their data into matrix
for vidIdx = 1:vidNo
    vidVector = nan(itemNo, 1);  % vector for collecting video-related item results
    
    for surIdx = 1:surNo
        
        % if corresponding file exists
        if fileCheck(vidIdx, surIdx)
            % load file
            tmp = load(surFiles{vidIdx, surIdx});
            
            % treat results depending on survey type
            if ismember(surveyTypes{surIdx}, {'seg1', 'seg2', 'seg3', 'seg4', 'seg5'})
                
                segIdx = surveyTypes{surIdx}(end); segIdx = str2double(segIdx);
                vidVector((segIdx-1)*5+1 : segIdx*5) = tmp.selects(:, 2);
                
            elseif strcmp(surveyTypes{surIdx}, 'pair')
                
                vidVector(26:34) = tmp.selects(:, 2);
    
            elseif strcmp(surveyTypes{surIdx}, 'indiv')
                
                vidVector(35:44) = tmp.selects(:, 2);              
                
            end  % if
            
            surveyData(:, vidIdx) = vidVector;
            
        end  % if fileCheck
        
    end  % for
    
end  % for vidIdx
disp('Loaded all data, collected into one matrix');            
            
saveFile = fullfile(baseDir, ['surveys_rater_', rater, '_67_233.mat']);
save(saveFile, 'surveyData', 'surFiles', 'fileCheck');
disp('Saved out data to: ');
disp(saveFile);

return
                
                
                
                
                
                
                
                
                
                
