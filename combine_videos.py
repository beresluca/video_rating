"""
CommGame project tools for subsequent video rater task.

Utility to combine videos from a CommGame freeConv task into one, combined video. The combined video shows
corresponding frames from source videos next to each other, on the same frame.

USAGE: python3 combine_videos.py INPUT_DIR PAIR_NO SESSION

Input args:
- INPUT_DIR:  Path to folder containing relevant videos for PAIR_NO and SESSION. The folder is globbed recursively.
- PAIR_NO:    Pair number.
- SESSION:    Name of the session the videos of which to combine. Defaults to freeConv, as other videos do not
              work yet (resolutions are not handled dynamically, relevant parameters are hardcoded).

Outputs:
- The combined video is saved out to an mp4 file at:
    [INPUT_DIR]/pair[PAIR_NO]_[SESSION]_combined_video.mp4
- Important timestamps are saved out to a npz (numpy) and to a mat file at:
    [INPUT_DIR]/pair[PAIR_NO]_[SESSION]_combined_video_start.npz
    [INPUT_DIR]/pair[PAIR_NO]_[SESSION]_combined_video_start.mat
  These files contain UNIX timestamps:
    absolute_start:     Real world frame capture timestamp (UNIX, in secs) for the first frame of the combined video.
                        CAUTION! This is not the timestamp of the first frames of the source videos, as we only use
                        the source videos from the nth frame, where "n" is hardcoded -see below.
                        The origin of this timestamp is the frameCaptTime var in the .mat files.
    shared_start_time:  Task initialization timestamp (UNIX, in secs) across the control PCs
                        (from sharedStartTime var in .mat files).
    relative_start:     The difference between absolute_start and shared_start_time, in seconds.

Notes:
- Uses glob to find the two (Mordor and Gondor lab) .mov files for a given pair and session.
- Videos are only combined from the "n"th frame on, because frame capture timestamps are variable (jitter) for the
  first few frames, probably due to an initial period needed for stable frame rate. "n" is defined as a constant
  (VIDEO_START_FRAME).
- Timestamps are extracted from relevant .mat files ("frameCaptTime", "sharedStartTime", "stopCaptureTime").
- If there is a discrepancy across the timestamps of the "n"th video frames, an adjustment is made,
  so that corresponding frames are found (details in combine_frames function).

"""

from scipy import io as sio
import numpy as np
import cv2
import glob
import argparse
import sys
import os


# Videos are combined from this frame on.
VIDEO_START_FRAME = 10
# Video frame resolution constants.
VIDEO_H = 1080
VIDEO_W = 1920
# Tolerance for frame capture time discrepancies, see function combine_frames for details.
CAPTURE_TIME_TOL_S = 0.02


def extract_video_times_mat(input_dir, pair_no, session):
    """
    Searches for .mat files containing sharedStartTime and other timestamps for given pair and session,
    then extracts timestamps and returns them in a dict.

    :param input_dir: Path to directory containing behavioral data. The script uses glob recursively to find .mat file.
    :param pair_no: Int, pair number
    :param session: Str, one of ['BG1', 'BG2', 'BG3', ..., 'BG9', 'freeConv', 'playback']

    :return: timestamps:  Dictionary with the following "key: value" pairs:
        start_time_m: Float, timestamp of task (recording) start, for Mordor lab recording
        stop_time_m: Float, timestamp of task (recording) end, for Mordor lab recording
        frame_times_m: Numpy array of frame capture timestamps, for Mordor lab recording
        start_time_g: Float, timestamp of task (recording) start, for Gondor lab recording
        stop_time_g: Float, timestamp of task (recording) end, for Gondor lab recording
        frame_times_g: Numpy array of frame capture timestamps, for Gondor lab recording

    (not returned anymore as earlier data misses it, and is not crucial: "vidcaptureStartTime" var from .mat files)
    """

    timestamps = {}
    # look for either **_times.mat or **_videoTimes.mat
    times_mat = glob.glob(f'{input_dir}/**/pair{pair_no}_Mordor_behav/pair{pair_no}_Mordor_{session}_**imes.mat',
                          recursive=True)[0]
    video_times = sio.loadmat(times_mat)
    timestamps['start_time_m'] = float(video_times['sharedStartTime'].flatten())
    timestamps['stop_time_m'] = float(video_times['stopCaptureTime'].flatten())
    # timestamps['start_time_capture_m'] = float(video_times['vidcaptureStartTime'].flatten())
    frame_times_m = video_times['frameCaptTime'].flatten()
    timestamps['frame_times_m'] = frame_times_m[np.logical_not(np.isnan(frame_times_m))]

    times_mat = glob.glob(f'{input_dir}/**/pair{pair_no}_Gondor_behav/pair{pair_no}_Gondor_{session}_**imes.mat',
                          recursive=True)[0]
    video_times = sio.loadmat(times_mat)
    timestamps['start_time_g'] = float(video_times['sharedStartTime'].flatten())
    timestamps['stop_time_g'] = float(video_times['stopCaptureTime'].flatten())
    # timestamps['start_time_capture_g'] = float(video_times['vidcaptureStartTime'].flatten())
    frame_times_g = video_times['frameCaptTime'].flatten()
    timestamps['frame_times_g'] = frame_times_g[np.logical_not(np.isnan(frame_times_g))]

    return timestamps


def count_frames_accurate(video_file):
    """
    Function to loop through each frame in a video, in order to get an exact frame count.
    Other (quicker) methods are generally less reliable and might return an erroneous count.

    VERY SLOW!

    :param video_file: Path to video file.
    :return: total:    Frame count.
    """
    # read in video
    video = cv2.VideoCapture(video_file)
    # initialize the total number of frames read
    total = 0
    # loop over the frames of the video
    while True:
        # grab the current frame
        (grabbed, frame) = video.read()
        # check to see if we have reached the end of the video
        if not grabbed:
            break
        # increment the total number of frames read
        total += 1
    # close video
    video.release()

    # return the total number of frames in the video file
    return total


def frame_connect(frame_left, frame_right):
    """
    Two high-def (1920 * 1080) frames (frame_left and frame_right) are resized and combined onto one frame.
    The resulting frame is also 1920 * 1080, with the upper 675 pixels filled with the two original frames side-by-side
    (left and right). 10-10% from the left and right sides of the original frames are cut before combining them.

    ONLY FOR FRAMES WITH 1920 * 1080 RES! RESOLUTION IS NOT CHECKED!

    :param frame_left:    Cv2 frame, res 1920 * 1080, to be used on the left side of the combined frame.
    :param frame_right:   Cv2 frame, res 1920 * 1080, to be used on the right side of the combined frame.
    :return: image:       3D numpy array corresponding to the combined frame, with dimensions
                          height (1080) * width (1920) * layers (3). Uint8 type.
    """
    # Resolution must be 1920*180!
    video_h = VIDEO_H
    video_w = VIDEO_W
    if video_h != 1080 or video_w != 1920:
        raise ValueError('Frame resolution is not 1920*180!!!!')
    # Input frames are first resized to 1200*675 (if input is - as it should be - 1920*1080)
    frame_l = cv2.resize(frame_left, (int(video_w/8*5), int(video_h/8*5)), interpolation=cv2.INTER_AREA)
    frame_r = cv2.resize(frame_right, (int(video_w/8*5), int(video_h/8*5)), interpolation=cv2.INTER_AREA)
    # Create black blank image
    image = np.zeros((video_h, video_w, 3), np.uint8)
    # Position the (horizontal) centers of resized input frames on the left and right
    image[0:int(video_h/8*5), 0:int(960)] = frame_l[:, 120:1080]
    image[0:int(video_h/8*5), int(960):int(1920)] = frame_r[:, 120:1080]

    return image


def frames_alignment(timestamps_m, timestamps_g, start_frame_no):
    """"
    Helper function to find corresponding frames of two videos, based on frame capture timestamps.
    !!! Half-done at the moment, use at own risk !!!
    """
    if timestamps_m[start_frame_no] >= timestamps_g[start_frame_no]:
        print('\n', start_frame_no, 'th frame happened later in Mordor.')
        start_frame_m = start_frame_no
        diffs = np.abs(timestamps_g-timestamps_m[start_frame_m])
        start_frame_g = np.where(diffs == np.min(diffs))[0][0]
        print('Minimum difference is maintained at starting frames:')
        print('Mordor:', start_frame_m, '; timestamp:', timestamps_m[start_frame_m])
        print('Gondor:', start_frame_g, '; timestamp:', timestamps_g[start_frame_g])
        print('Difference:', timestamps_m[start_frame_m]-timestamps_g[start_frame_g])
    elif timestamps_m[start_frame_no] < timestamps_g[start_frame_no]:
        print('\n', start_frame_no, 'th frame happened later in Gondor.')
        start_frame_g = start_frame_no
        diffs = np.abs(timestamps_m-timestamps_g[start_frame_g])
        start_frame_m = np.where(diffs == np.min(diffs))[0][0]
        print('Minimum difference is maintained at starting frames:')
        print('Mordor:', start_frame_m, '; timestamp:', timestamps_m[start_frame_m])
        print('Gondor:', start_frame_g, '; timestamp:', timestamps_g[start_frame_g])
        print('Difference:', timestamps_m[start_frame_m]-timestamps_g[start_frame_g])
    else:
        raise ValueError('Invalid timestamps???')

    return start_frame_m, start_frame_g


def combine_frames(input_dir, pair_no, session='freeConv', start_frame=10, slow_frame_count=False):
    """
    Main function that loads timestamps, videos and loops through their corresponding frames, combining them.

    :param input_dir:        Path to folder containing the video and timestamp files for given pair and session.
                             glob-ed recursively for relevant files.
    :param pair_no:          Numeric value, pair number.
    :param session:          Str, session name. Only support 'freeConv' at the moment! Defaults to 'freeConv'.
    :param start_frame:      Numeric value, the frame number we start the frame combinations from. Initial frames have
                             jittery frame capture times, so - by default - we only start video combinations
                             from this frame on. Defaults to 10.
    :param slow_frame_count: Boolean flag for using the slow frame-counting method (count_frame_accurate, which loops
                             through the frames)

    :return: abs_video_start:   Unix timestamp in seconds, frame capture time for the vide frame we start from.
    :return: shared_start_time: Unix timestamp in seconds, shared start time for session in synchronized, cross-lab time.
    :return: relative_start:    Numeric value, difference between abs_video_start and shared_start_time in seconds.
    :return: output_path:       Str, path to the saved-out combined video (mp4) file.

    File output!
    The combined video is saved out to an mp4 file at:
    [INPUT_DIR]/pair[PAIR_NO]_[SESSION]_combined_video.mp4

    Notes:
    - If the 'start_frame'th video frames are not aligned well enough across the two videos, an adjustment is made.
      In this case, the latter of the 'start_frame'th frames are treated as the reference, and the corresponding frame
      from the other video is identified based on the frame capture timestamps.
      Then a further check is made for subsequent frames, and if there remain discrepancies, a simple matching is made
      across all videoframes so that we combine the truly corresponding frames only.
    - Only works with input video resolutions 1920 * 1080. Checks video res and aborts for different values.
    """

    # PARAMS
    # Maximum allowed discrepancy across "corresponding" frame capture timestamps, in seconds.
    # For a sampling rate of 30 Hz (1 frame per 33.3 ms), maximal distance across truly corresponding frames should
    # be only 16.7 ms, so 20 ms is a liberal tolerance value
    capture_time_tol = CAPTURE_TIME_TOL_S
    # Expected video frame resolution, current version only works properly with these values,
    # good for freeConv videos but not for 1280 x 720 BG videos
    expected_h = VIDEO_H
    expected_w = VIDEO_W

    # Define output movie filename.
    output_path = os.path.join(input_dir, 'pair' + str(pair_no) + '_' + session + '_combined_video.mp4')

    # Find video files.
    video_mordor = glob.glob(f'{input_dir}/**/pair{pair_no}_Mordor_behav/pair{pair_no}_Mordor_{session}.mov',
                             recursive=True)[0]
    video_gondor = glob.glob(f'{input_dir}/**/pair{pair_no}_Gondor_behav/pair{pair_no}_Gondor_{session}.mov',
                             recursive=True)[0]

    if video_mordor and video_gondor:
        print('\nFound video files:')
        print(video_mordor)
        print(video_gondor)
    else:
        print('\nFound no video files!')
        sys.exit()

    # Open video files with opencv.
    cap_mordor = cv2.VideoCapture(video_mordor)
    cap_gondor = cv2.VideoCapture(video_gondor)
    print('\nOpened video files...')

    # Fetch and print basic video properties.
    video_m_fps = cap_mordor.get(cv2.CAP_PROP_FPS)
    video_m_h = cap_mordor.get(cv2.CAP_PROP_FRAME_HEIGHT)
    video_m_w = cap_mordor.get(cv2.CAP_PROP_FRAME_WIDTH)
    video_g_fps = cap_gondor.get(cv2.CAP_PROP_FPS)
    video_g_h = cap_gondor.get(cv2.CAP_PROP_FRAME_HEIGHT)
    video_g_w = cap_gondor.get(cv2.CAP_PROP_FRAME_WIDTH)

    # If the slow_frame_count flag is set, count the frames of the videos with the slow but accurate method.
    # The method below takes too much time, only use it for troubleshooting, if there is stg fishy about frame numbers.
    if slow_frame_count:
        video_m_fc = count_frames_accurate(video_mordor)
        video_g_fc = count_frames_accurate(video_gondor)
    # Else we just go with what cv2 reports
    else:
        video_m_fc = cap_mordor.get(cv2.CAP_PROP_FRAME_COUNT)
        video_g_fc = cap_gondor.get(cv2.CAP_PROP_FRAME_COUNT)

    print('\nMordor video properties:')
    print('fps: ' + str(video_m_fps) + '; height: ' + str(video_m_h) +
          '; width: ' + str(video_m_w) + '; frame count: ' + str(video_m_fc))
    print('Gondor video properties:')
    print('fps: ' + str(video_g_fps) + '; height: ' + str(video_g_h) +
          '; width: ' + str(video_g_w) + '; frame count: ' + str(video_g_fc))

    # Sanity checks for resolution and for matching fps.
    if video_m_fps != video_g_fps or video_m_h != video_g_h or video_m_w != video_g_w:
        raise ValueError('Video properties do not match!')
    if video_m_h != expected_h or video_m_w != expected_w:
        raise ValueError(' '.join(['Unexpected frame size! Should be', str(VIDEO_W), 'x', str(VIDEO_H),
                                   'for both videos!']))

    # extract timestamps
    timestamps = extract_video_times_mat(input_dir, pair_no, session)
    capt_times_m = timestamps['frame_times_m']
    capt_times_g = timestamps['frame_times_g']
    shared_start_time = timestamps['start_time_m']
    # check if the "start_frame"th timestamps line up nicely or not
    if np.abs(capt_times_m[start_frame] - capt_times_g[start_frame]) > capture_time_tol:
        print('\nTiming difference at 10th video frame too large across Mordor and Gondor!')
        print('Difference is ', np.abs(capt_times_m[start_frame] - capt_times_g[start_frame]),
              '(positive value means Mordor capture timestamp is larger, that is, happened later)')
        print('WARNING')
        print('Will attempt to line up truly corresponding frames from the two videos.',
              '\nThere is absolutely no guarantee that this works though.')
        # call alignment repair function
        start_frame_m, start_frame_g = frames_alignment(capt_times_m, capt_times_g, start_frame)
    else:
        start_frame_m = start_frame
        start_frame_g = start_frame
    # get video start timestamps
    abs_video_start_m = capt_times_m[start_frame_m]
    abs_video_start_g = capt_times_g[start_frame_g]
    abs_video_start = (abs_video_start_m + abs_video_start_g) / 2
    relative_start = abs_video_start - shared_start_time
    print('\nAbsolute, shared and relative starts for combined video:')
    print((abs_video_start, shared_start_time, relative_start))

    # args for the video output
    fps_out = video_m_fps
    size_out = (int(video_m_w), int(video_m_h))

    # prepare writer object
    # fourcc = cv2.VideoWriter.fourcc('M', 'J', 'P', 'G')  # not preferred format
    fourcc = cv2.VideoWriter.fourcc('m', 'p', '4', 'v')
    video_writer = cv2.VideoWriter(output_path, fourcc, fps_out, size_out)
    print('\nOpened and prepared video writer...')


    ##################################
    # connect frames
    ##################################

    # counters, flags
    release_flag = False
    frame_counter_m = 0
    frame_counter_g = 0
    frame_counter_out = 0
    # read frames until before hitting the starting frames for both videos
    while frame_counter_m < start_frame_m:
        ret_m, frame_m = cap_mordor.read()
        frame_counter_m += 1
    while frame_counter_g < start_frame_g:
        ret_g, frame_g = cap_gondor.read()
        frame_counter_g += 1

    # main loop for connecting frames for joint output video
    while not release_flag:
        # check for user interrupt
        if cv2.waitKey(1) & 0xFF == ord('q'):
            release_flag = True

        # read next frames
        ret_m, frame_m = cap_mordor.read()
        ret_g, frame_g = cap_gondor.read()
        # if there are frames
        if ret_m and ret_g:
            # join and write current frames
            img = frame_connect(frame_m, frame_g)
            video_writer.write(img)
            # user feedback
            if frame_counter_out % 1000 == 0:
                print('Written ' + str(frame_counter_out) + ' frames...')
            # adjust counters
            frame_counter_m += 1
            frame_counter_g += 1
            frame_counter_out += 1
        # if either video is it at its end, abort
        else:
            release_flag = True

    # clean up, once the while loop (=video writing) is over
    print('Done, closing shop')
    print('Output video contains', frame_counter_out - 1, 'frames.')
    video_writer.release()
    cv2.destroyAllWindows()
    print('Closed video writer, all done and done.')

    return abs_video_start, shared_start_time, relative_start, output_path


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('input_dir', help='Path to the dir containing audio and corresponding .mat files')
    parser.add_argument('pair_no', type=int, help='Pair number (between 1-999)')
    parser.add_argument('session', type=str, default='freeConv',
                        help='Name of the recording session (BG1, ... BG9, freeConv, playback). '
                             'Only supports freeConv at the moment. Defaults to freeConv.')
    args = parser.parse_args()

    abs_video_start_t, shared_start_t, relative_start_t, _ = combine_frames(args.input_dir, args.pair_no, args.session)
    output_file = os.path.join(args.input_dir,
                               'pair' + str(args.pair_no) + '_' + args.session + '_combined_video_start')
    np.savez(output_file, absolute_start=abs_video_start_t, shared_start=shared_start_t, rel_start=relative_start_t)
    sio.savemat(output_file + '.mat', {'absolute_start': abs_video_start_t,
                                       'shared_start': shared_start_t,
                                       'rel_start': relative_start_t})
    print('\nAu revoir, adios, ha det bra, cheerios!')
