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
  --dataset.root=/home/george/.cache/huggingface/lerobot/gigwegbe/first-dataset \
  --dataset.single_task="first dataset" \
  --dataset.num_episodes=45 \
  --dataset.fps=30 \
  --dataset.reset_time_s=10 \
  --dataset.push_to_hub=false \
  --resume=true