import os
import rawpy
import numpy as np

# 定义文件夹路径
folder_path = 'D:\code\data\dng_five_star'  # 替换为你的文件夹路径

# 遍历文件夹中的所有 .dng 文件
for filename in os.listdir(folder_path):
    if filename.lower().endswith('.dng'):
        dng_path = os.path.join(folder_path, filename)
        raw_path = os.path.join(folder_path, os.path.splitext(filename)[0] + '.raw')

        try:
            # 读取 DNG 文件
            with rawpy.imread(dng_path) as raw:
                # 获取原始图像数据
                raw_data = raw.raw_image

                # 将数据保存为 .raw 文件
                raw_data.tofile(raw_path)
                print(f"成功将 {filename} 转换为 {os.path.basename(raw_path)}")
        except Exception as e:
            print(f"处理 {filename} 时发生错误: {e}")