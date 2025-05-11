import requests

def process_video(api_url: str, video_path: str):
    """
    Uploads a video to the FastAPI endpoint and returns the JSON response.
    """
    with open(video_path, 'rb') as f:
        files = {'IN_VIDEO': (video_path, f, 'video/mp4')}
        response = requests.post(f"{api_url}/process_video/", files=files)
        response.raise_for_status()
        return response.json()

if __name__ == "__main__":
    api_url = "http://0.0.0.0:8000"
    video_path = "D055_04.avi"

    result = process_video(api_url, video_path)
    print("API returned:")
    print(result)