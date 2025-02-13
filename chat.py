import requests

# OpenAI API 端点
API_URL = "https://api.openai.com/v1/chat/completions"
# 替换为你的 OpenAI API Key
API_KEY = "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"

def ask_chatgpt(question):
    headers = {
        "Authorization": f"Bearer {API_KEY}",
        "Content-Type": "application/json"
    }
    
    data = {
        "model": "gpt-3.5-turbo",
        "messages": [
            {"role": "system", "content": "You are a helpful assistant."},
            {"role": "user", "content": question}
        ],
        "temperature": 0.7
    }
    
    response = requests.post(API_URL, json=data, headers=headers)
    
    if response.status_code == 200:
        return response.json()["choices"][0]["message"]["content"]
    else:
        return f"Error: {response.status_code}, {response.text}"

if __name__ == "__main__":
    while True:
        question = input("请输入你的问题（输入 'exit' 退出）：")
        if question.lower() == "exit":
            break
        answer = ask_chatgpt(question)
        print("ChatGPT 回答:", answer)
