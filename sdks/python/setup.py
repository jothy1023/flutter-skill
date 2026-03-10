from setuptools import setup, find_packages

setup(
    name="pytest-flutter-skill",
    version="0.1.0",
    description="pytest plugin for flutter-skill AI app automation",
    long_description=open("README.md").read(),
    long_description_content_type="text/markdown",
    author="flutter-skill contributors",
    url="https://github.com/ai-dashboad/flutter-skill",
    packages=find_packages(),
    python_requires=">=3.9",
    install_requires=["pytest>=7.0"],
    entry_points={
        "pytest11": ["flutter_skill = pytest_flutter_skill.fixture"],
    },
    classifiers=[
        "Framework :: Pytest",
        "Programming Language :: Python :: 3",
        "License :: OSI Approved :: MIT License",
        "Operating System :: OS Independent",
    ],
)
