rm -rf /home/george/.cache/huggingface/lerobot/gigwegbe/first-dataset

export CAMERA_FRONT=4
export CAMERA_EXTERNAL=2
export CAMERA_WRIST=6


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
      "index_or_path": '"$CAMERA_WRIST"',
      "width": 640,
      "height": 480,
      "fps": 30,
    },
    "front": {
      "type": "opencv",
      "index_or_path": '"$CAMERA_FRONT"',
      "width": 640,
      "height": 480,
      "fps": 30,
      "fourcc": "MJPG"
    },
    "top": {
      "type": "opencv",
      "index_or_path": '"$CAMERA_EXTERNAL"',
      "width": 640,
      "height": 480,
      "fps": 30
    }
  }' \
  --dataset.repo_id=gigwegbe/first-dataset \
  --dataset.root=/home/george/.cache/huggingface/lerobot/gigwegbe/first-dataset \
  --dataset.single_task="first dataset" \
  --dataset.num_episodes=10 \
  --dataset.fps=30 \
  --dataset.reset_time_s=10 \
  --dataset.push_to_hub=false \
  --resume=true



# without the camera
  lerobot-replay \
  --robot.type=so101_follower \
  --robot.port="$ROBOT_PORT" \
  --robot.id="$ROBOT_ID" \
  --dataset.repo_id=gigwegbe/first-dataset \
  --dataset.root=/home/george/.cache/huggingface/lerobot/gigwegbe/first-dataset \
  --dataset.episode=3