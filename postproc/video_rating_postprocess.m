%%
% Cleaned up script for processing video ratings from the freeConv task
% (CommGame experiment). 
% 
% The input datastruct is a .mat file created by collectSurveyData.m and
% allRaters.m scripts, containing all ratings from all (8) raters. For each
% video there has to be at least 2 ratings, in some cases (where agreement
% was unsatisfactory) there are 3. 
%
% The script calculates agreement with Intraclass Correlations (ICC) and Mean 
% Absolute Difference (MAD).
% Calculations are done across all 3 rater's ratings (where possible),
% then, we choose the pairing with the highest agreement based on an
% aggragate value of ICC and MAD. The final value is then the mean of the
% two ratings.
% 
%%

% load data
baseDir = '/home/lucab/video_rating_scripts/';
dataStruct = load('/home/lucab/video_rating_scripts/surveys_raters_all_67_233.mat');
allData = dataStruct.allData;

% hardcoded parameters of ratings data
no_items = 44;
no_videos = 167;
no_raters = 8;

pairNos = 67:233;

quest_items = readtable('/home/lucab/video_rating_scripts/video_rating_quest_items.csv');

%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Main loop for creating matrix with mean values %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

mean_ratings_videos = zeros(no_items, no_videos);
means_non_zscored = zeros(no_items, no_videos);
icc_all = zeros(no_videos, 3);
MAD_all = zeros(no_videos, 3);
aggrMAD_ICC_all = zeros(no_videos, 3);
rater_pairings_keys = {'Rater 1 x Rater 2 (original raters)', 'Rater 2 x Rater 3', 'Rater 3 x Rater 1'};
raters_names_videos = cell(no_videos, 3);

for v=1:no_videos
    
    % calculate ICC and mean abs difference between all possible pairings
    % (3) of raters 
    current_video = squeeze(allData(:,v,:));
    rater_names = dataStruct.raters;
    
    % get info about which raters rated the current video
    rater_pairs_names = {};
    rater_pairs_idx = {};
    for rIdx = 1:length(rater_names)
        if ~isnan(current_video(rIdx,1))
            rater_pairs_names = [rater_pairs_names, rater_names{rIdx}];
            rater_pairs_idx = [rater_pairs_idx, rIdx];
        end
    end
    
    raters_names_videos{v,1} = rater_pairs_names{1};
    raters_names_videos{v,2} = rater_pairs_names{2};
    if length(rater_pairs_names) == 3
        raters_names_videos{v,3} = rater_pairs_names{3};
    end
            
    % for each rater get mean and std of their ratings across all videos
    % (used for zscoring each value later)
    rater1_all = squeeze(allData(rater_pairs_idx{1},:,:));
    rater2_all = squeeze(allData(rater_pairs_idx{2},:,:));
    rater1_mean = mean(rater1_all(:), 'omitnan');  % cannot use the "all" flag in 2017a version of matlab...
    rater2_mean = mean(rater2_all(:),'omitnan');
    rater1_std = std(rater1_all(:),'omitnan');
    rater2_std = std(rater2_all(:),'omitnan');

    
    if length(rater_pairs_idx) == 3
        % we also need descriptives for the third rater if there is one
        rater3_all = squeeze(allData(rater_pairs_idx{3},:,:));
        rater3_mean = mean(rater3_all(:),'omitnan');
        rater3_std = std(rater3_all(:),'omitnan');
        
        % get all ratings for given video per rater
        rater1 = current_video(cell2mat(rater_pairs_idx(1)),:,:);
        rater2 = current_video(cell2mat(rater_pairs_idx(2)),:,:);
        rater3 = current_video(cell2mat(rater_pairs_idx(3)),:,:);
        
        % ICC
        ICC_result_original = f_ICC([rater1; rater2]', 0.05);
        ICC_result_2by3 = f_ICC([rater2; rater3]', 0.05);
        ICC_result_3by1 = f_ICC([rater3; rater1]', 0.05);
        icc2k_original = ICC_result_original{1,5}.est;
        icc2k_2by3 = ICC_result_2by3{1,5}.est;
        icc2k_3by1 = ICC_result_3by1{1,5}.est;
        icc_all(v,1) = icc2k_original;
        icc_all(v,2) = icc2k_2by3;
        icc_all(v,3) = icc2k_3by1;
        
        % MAD
        MAD_original = abs(mean(rater1 - rater2));
        MAD_2by3 = abs(mean(rater2 - rater3));
        MAD_3by1 = abs(mean(rater3 - rater1));
        MAD_all(v,1) = MAD_original;
        MAD_all(v,2) = MAD_2by3;
        MAD_all(v,3) = MAD_3by1;
              
        % aggregate of ICC and MAD
        aggr_original = icc2k_original - (0.5 * MAD_original);
        aggr_2by3 = icc2k_2by3 - (0.5 * MAD_2by3);
        aggr_3by1 = icc2k_3by1 - (0.5 * MAD_3by1);
        aggrMAD_ICC_all(v,1) = aggr_original;
        aggrMAD_ICC_all(v,2) = aggr_2by3;
        aggrMAD_ICC_all(v,3) = aggr_3by1;
        
        % perform z-scoring on all ratings of current video using the mean
        % and std from above
        rater1_z = bsxfun(@rdivide, bsxfun(@minus, rater1, rater1_mean), rater1_std);
        rater2_z = bsxfun(@rdivide, bsxfun(@minus, rater2, rater2_mean), rater2_std);
        rater3_z = bsxfun(@rdivide, bsxfun(@minus, rater3, rater3_mean), rater3_std);
        
        % calculate mean based on biggest aggregate value
        [x, ind] = max([aggr_original, aggr_2by3, aggr_3by1]);
        if ind == 1
           mean_ratings_videos(:,v) = mean([rater1_z', rater2_z'], 2);
           means_non_zscored(:,v) = mean([rater1', rater2'], 2);
        elseif ind == 2
           mean_ratings_videos(:,v) = mean([rater2_z', rater3_z'], 2);
           means_non_zscored(:,v) = mean([rater2', rater3'], 2);
        elseif ind == 3
           mean_ratings_videos(:,v) = mean([rater3_z', rater1_z'], 2);
           means_non_zscored(:,v) = mean([rater3', rater1'], 2);
        end           
        
    elseif length(rater_pairs_idx) == 2
        % if we only have 2 raters for a video, we won't calculate ICC and
        % MAD
        % get all ratings for given video per rater
        rater1 = current_video(cell2mat(rater_pairs_idx(1)),:,:);
        rater2 = current_video(cell2mat(rater_pairs_idx(2)),:,:);
        % then z-score
        rater1_z = bsxfun(@rdivide, bsxfun(@minus, rater1, rater1_mean), rater1_std);
        rater2_z = bsxfun(@rdivide, bsxfun(@minus, rater2, rater2_mean), rater2_std);
        % calculate mean for 2 raters
        mean_ratings_videos(:,v) = mean([rater1_z', rater2_z'], 2);
        means_non_zscored(:,v) = mean([rater1', rater2'], 2);
        
%     % it's still here, but hopefully not needed (?)    
%     elseif isempty(rater_pairs_idx)
%         mean_ratings_videos(i,v) = NaN;
%         disp(['Found an empty row for video: ', num2str(v), '! Will set it to NaN!']);
%     elseif length(rater_pairs_idx) == 1
%         mean_ratings_videos(i,v) = 
    end

end

% Save the newly created data in a .mat file
save_filename = fullfile(baseDir, ['freeConv_ratings_preprocessed_', num2str(pairNos(1)), '_', num2str(pairNos(length(pairNos))) '.mat']);
save(save_filename, 'mean_ratings_videos', 'means_non_zscored', 'quest_items', ...
                    'pairNos', 'aggrMAD_ICC_all', 'raters_names_videos', 'rater_pairings_keys');
disp('Processed datafile (.mat) saved at: ');
disp(save_filename);

tmp = [pairNos; mean_ratings_videos];
tmp = transpose(tmp);
T = array2table(tmp);
save_csv = fullfile(baseDir, ['freeConv_ratings_zscored_', num2str(pairNos(1)), '_', num2str(pairNos(length(pairNos))), '.csv']);
writetable(T, save_csv, 'Delimiter', ',', 'WriteVariableNames', 0);
disp('Result is also saved to csv file at:');
disp(save_csv);


% hist([mean_ratings_videos(1,:), mean_ratings_videos(6,:), mean_ratings_videos(11,:), mean_ratings_videos(16,:), mean_ratings_videos(21,:)], 7)

tmp_csv = readtable("/home/lucab/Documents/commgame_conditions.csv");
cond_table = tmp_csv(tmp_csv.Pair >= 67,:);
cond_table = unique(cond_table);  % need this step because we have duplicate rows in the csv!

baseline_pairs = strcmp(cond_table.Condition, 'alap');
unimodal_pairs = strcmp(cond_table.Condition, 'unimodális');
unfamiliar_pairs = strcmp(cond_table.Condition, 'ismeretlen');
competitive_pairs = strcmp(cond_table.Condition, 'versengő');

% corr(mean_ratings_videos(26,:), mean_ratings_videos(34,:))

% figure
% histogram(mean_ratings_videos(26, unfamiliar_pairs), 7, 'FaceColor', 'g')
% hold on
% histogram(mean_ratings_videos(26, baseline_pairs), 7, 'FaceColor', 'b')
% hold on
% histogram(mean_ratings_videos(26, unimodal_pairs), 7, 'FaceColor', 'r')
% legend('Unfamiliar', 'Baseline', 'Unimodal')
% title('"A beszélgetést gördülékenynek, természetesnek éreztem."')





