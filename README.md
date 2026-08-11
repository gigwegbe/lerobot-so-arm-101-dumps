 # SO-101: Teleop, Cameras, Hands-Free Recording, and Dataset Visualization

Notes from getting a full teleop → record → visualize loop working on the real SO-101, plus a hands-free foot pedal setup for episode control.

## 1. Port and ID setup

Leader and follower show up as separate `/dev/ttyACM*` serial devices. These can shift after a replug or process kill, so always confirm before running anything:

```bash
ls /dev/ttyACM* /dev/ttyUSB*
```

If unsure which port is which arm, walk through them one at a time:

```bash
lerobot-find-port
```

Set env vars once confirmed:

```bash
export TELEOP_PORT=/dev/ttyACM0
export ROBOT_PORT=/dev/ttyACM1
export TELEOP_ID=orange_teleop
export ROBOT_ID=orange_robot
```

## 2. Calibration

Run once per arm before teleoperating:

```bash
lerobot-calibrate \
  --teleop.type=so101_leader \
  --teleop.port=/dev/ttyACM0 \
  --teleop.id=orange_teleop

lerobot-calibrate \
  --robot.type=so101_follower \
  --robot.port=/dev/ttyACM1 \
  --robot.id=orange_robot
```

Optional sanity check script: `so101_check_calibration.py`.

## 3. Finding working cameras

```bash
lerobot-find-cameras opencv
```

Lessons learned here:

- Detected indices can include dead ports. One camera (`/dev/video6` in this session) showed up as detected but failed with `read failed (status=False)` — it never actually produced frames. Detected ≠ working; always test a real frame read.
- OpenCV camera indices are not stable identifiers — they can shift between sessions depending on what else is plugged in or what order devices enumerate.
- To positively identify which physical camera is which (wrist vs front), grab a snapshot from each candidate index and inspect it:

```python
import cv2
for idx in [0, 2, 4]:
    cap = cv2.VideoCapture(idx)
    ret, frame = cap.read()
    if ret:
        cv2.imwrite(f"/tmp/cam_{idx}.jpg", frame)
        print(f"Camera {idx}: saved")
    else:
        print(f"Camera {idx}: failed to read")
    cap.release()
```

Once confirmed:

```bash
export CAMERA_GRIPPER=2
export CAMERA_EXTERNAL=4
```

## 4. Teleoperation

```bash
lerobot-teleoperate \
  --robot.type=so101_follower \
  --robot.port="$ROBOT_PORT" \
  --robot.id="$ROBOT_ID" \
  --teleop.type=so101_leader \
  --teleop.port="$TELEOP_PORT" \
  --teleop.id="$TELEOP_ID" \
  --display_data=true \
  --robot.cameras='{
    "wrist": {
      "type": "opencv",
      "index_or_path": '"$CAMERA_GRIPPER"',
      "width": 640,
      "height": 480,
      "fps": 30
    },
    "front": {
      "type": "opencv",
      "index_or_path": '"$CAMERA_EXTERNAL"',
      "width": 640,
      "height": 480,
      "fps": 30
    }
  }'
```

Errors hit and fixed along the way:

- `ConnectionError: Failed to open OpenCVCamera(2)` — camera index had shifted after a replug. Fixed by re-running `lerobot-find-cameras opencv` and updating the index.
- `ConnectionError: Failed to write 'Torque_Enable' on id_=3 ... There is no status packet!` — a servo bus communication failure, not a camera issue. Cause was a stale process still holding the serial port after a previous run. Fixed by clearing all lingering LeRobot processes first:

```bash
pkill -9 -f lerobot
ps aux | grep lerobot   # to inspect before killing, if needed
```

- To exit teleoperate cleanly: **Ctrl+C** in the terminal. This lets LeRobot disable torque and release the camera/serial handles properly — closing the terminal window instead can leave the port locked.

## 5. Hands-free episode control with a foot pedal

Used a generic 3-button PCsensor USB foot pedal (shows up as a standard HID keyboard, no drivers needed) to drive `lerobot-record` without touching the keyboard.

**Tool:** [`footswitch`](https://github.com/rgerganov/footswitch) by rgerganov — a Linux CLI that writes the key mapping directly into the pedal's onboard memory (persistent across replugs/machines).

```bash
git clone https://github.com/rgerganov/footswitch
cd footswitch
make
sudo make install   # also installs a udev rule, so sudo isn't needed after a replug
```

Check detection:

```bash
lsusb | grep -i pc
# Bus 001 Device 092: ID 3553:b001 PCsensor FootSwitch
```

Read current mapping:

```bash
footswitch -r
```

LeRobot's recorder uses **right arrow** (accept episode, move on), **left arrow** (re-record), and **escape** (stop session). Two gotchas discovered while setting this up:

1. **Named keys aren't all recognized.** `-k right` and `-k left` silently failed and left those pedals `unconfigured`, while `-k esc` worked fine. Fix: use raw USB HID usage codes instead of key names:
   - Right Arrow = `4F`
   - Left Arrow = `50`

2. **The pedal firmware stores all three mappings as a single config block.** Setting pedals one command at a time causes each new write to blank out the other two. Fix: set all three pedals in **one single invocation**:

```bash
footswitch -1 -S '4F' -2 -S '50' -3 -k esc
footswitch -r
# [switch 1]: <right>
# [switch 2]: <left>
# [switch 3]: esc
```

Usage during recording:

- **Right pedal** → end current episode, move to next
- **Left pedal** → discard and re-record current episode
- **Center pedal** → stop the whole session (esc)

If a pedal seems to do the wrong thing, re-check `footswitch -r` first (confirm the firmware mapping didn't revert) before assuming a physical mix-up between pedal positions.

## 6. Recording a dataset

```bash
lerobot-record \
  --robot.type=so101_follower \
  --robot.port="$ROBOT_PORT" \
  --robot.id="$ROBOT_ID" \
  --teleop.type=so101_leader \
  --teleop.port="$TELEOP_PORT" \
  --teleop.id="$TELEOP_ID" \
  --display_data=true \
  --robot.cameras='{
    "wrist": {
      "type": "opencv",
      "index_or_path": '"$CAMERA_GRIPPER"',
      "width": 640,
      "height": 480,
      "fps": 30
    },
    "front": {
      "type": "opencv",
      "index_or_path": '"$CAMERA_EXTERNAL"',
      "width": 640,
      "height": 480,
      "fps": 30
    }
  }' \
  --dataset.repo_id=gigwegbe/first-dataset \
  --dataset.single_task="first dataset" \
  --dataset.num_episodes=50 \
  --dataset.fps=30 \
  --dataset.reset_time_s=10 \
  --dataset.push_to_hub=false
```

Notes:

- `--dataset.push_to_hub=false` keeps the dataset local only (at `~/.cache/huggingface/lerobot/<repo_id>`), since `lerobot-record` pushes to the Hub by default otherwise.
- `--dataset.reset_time_s` gives a pause between episodes to reset the scene before the next one starts recording automatically.
- Each completed episode gets encoded with SVT-AV1 — the `Svt[info]` log lines after an episode ends are normal, not errors.
- Hit a `ValueError: You must add one or several frames with add_frame before calling add_episode` crash once — caused by stopping (esc) right as a new, still-empty episode buffer opened. Earlier completed episodes remained safely saved; only the empty in-progress one failed. Lesson: let a couple of frames land (wait a beat after "Recording episode N" appears) before hitting the stop pedal, or stop during the reset window between episodes rather than mid-recording.

## 7. Visualizing a recorded dataset

```bash
lerobot-dataset-viz \
  --repo-id gigwegbe/first-dataset \
  --root ~/.cache/huggingface/lerobot/gigwegbe/first-dataset/ \
  --episode-index 0
```

- `--episode-index` is required — the visualizer shows one episode at a time, not the whole dataset in a single view. Swap the index to page through others.
- `--root` is required for local-only datasets (not pushed to the Hub) — without it, the tool tries to fetch from the Hub and fails.
- Opens a Rerun-based UI similar to the one used during live recording, but lets you scrub through saved episodes after the fact.
- To check how many episodes actually saved:

```bash
ls ~/.cache/huggingface/lerobot/gigwegbe/first-dataset/data/chunk-000/ | wc -l
```

## 8. Async policy inference client (for reference)

Used to run a remote policy server (e.g. Pi0.5 on a Mac) against the real robot over the network:

```bash
python -m lerobot.async_inference.robot_client \
  --server_address=192.168.1.66:8080 \
  --robot.type=so101_follower \
  --robot.port=/dev/ttyACM2 \
  --robot.id=orange_robot \
  --robot.cameras="{left_wrist_0_rgb: {type: opencv, index_or_path: 3, width: 640, height: 480, fps: 30}, right_wrist_0_rgb: {type: opencv, index_or_path: 0, width: 640, height: 480, fps: 30}, base_0_rgb: {type: opencv, index_or_path: 5, width: 640, height: 480, fps: 30}}" \
  --task="pick up the vial and place it in the rack" \
  --policy_type=pi05 \
  --pretrained_name_or_path=/Users/george/Projects/lero/models/pi05_base \
  --policy_device=mps \
  --actions_per_chunk=50
```

Note the camera key names differ from teleop/record (`left_wrist_0_rgb`, `right_wrist_0_rgb`, `base_0_rgb`) — these must match what the specific policy (Pi0.5 here) expects, not the generic `wrist`/`front` naming used elsewhere.

## 9. Isaac Lab sim-side teleop and recording

The same leader arm can drive a simulated SO-101 in Isaac Lab instead of (or alongside) the real follower — useful for testing tasks in sim before running them on hardware.

Basic teleop against the sim:

```bash
cd ~/Documents/new-lab/IsaacLab-5.1
./isaaclab.sh -p -m sim_to_real_so101.scripts.lerobot_agent --task Lerobot-So101-Teleop-Base
```

Recording a sim dataset for a specific task (here, a vials-to-rack pick-and-place task):

```bash
./isaaclab.sh -p -m sim_to_real_so101.scripts.lerobot_agent \
  --task Lerobot-So101-Teleop-Vials-To-Rack \
  --repo_id <your-hf-username>/vials-to-rack \
  --repo_root ./datasets/vials
```

Both commands run through `isaaclab.sh -p -m`, Isaac Lab's own Python module launcher, rather than the plain `lerobot-*` CLI entry points used for the real robot — the task name (`--task`) selects which registered Isaac Lab environment to load.

## 10. Cleanup

If ports lock up, cameras won't reconnect, or a session hangs:

```bash
pkill -9 -f lerobot
ps aux | grep lerobot
```

Then re-verify ports (`ls /dev/ttyACM*`) and cameras (`lerobot-find-cameras opencv`) before starting again — indices and enumeration order aren't guaranteed to stay the same across restarts.