#include "main_window.h"

#include <QDateTime>
#include <QFile>
#include <QHBoxLayout>
#include <QPixmap>
#include <QTextStream>
#include <QVBoxLayout>

MainWindow::MainWindow(QWidget *parent) : QMainWindow(parent) {
    buildUi();
    connect(&refreshTimer, &QTimer::timeout, this, &MainWindow::refreshResult);
    refreshTimer.start(1000);
}

void MainWindow::buildUi() {
    auto *root = new QWidget(this);
    auto *layout = new QHBoxLayout(root);

    auto *left = new QVBoxLayout();
    statusLabel = new QLabel("Previewing, waiting for PCB", root);
    summaryLabel = new QLabel("No result loaded", root);
    refreshButton = new QPushButton("Refresh Result", root);
    continueButton = new QPushButton("Continue", root);

    left->addWidget(statusLabel);
    left->addWidget(summaryLabel);
    left->addStretch();
    left->addWidget(refreshButton);
    left->addWidget(continueButton);

    imageLabel = new QLabel("Camera preview area", root);
    imageLabel->setAlignment(Qt::AlignCenter);
    imageLabel->setMinimumSize(640, 480);
    imageLabel->setStyleSheet("background:#202533;color:white;");

    layout->addLayout(left, 1);
    layout->addWidget(imageLabel, 3);
    setCentralWidget(root);
    setWindowTitle("PCB Defect Detection System");
    resize(1200, 760);

    connect(refreshButton, &QPushButton::clicked, this, &MainWindow::refreshResult);
    connect(continueButton, &QPushButton::clicked, this, &MainWindow::continueInspection);
}

void MainWindow::refreshResult() {
    loadResultText("runtime/output/result.txt");
    loadResultImage("runtime/output/result.jpg");
}

void MainWindow::continueInspection() {
    QFile file("runtime/continue.flag");
    if (file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        QTextStream out(&file);
        out << "CONTINUE\n" << QDateTime::currentDateTime().toString("yyyy-MM-dd HH:mm:ss") << "\n";
    }
    statusLabel->setText("Waiting for next PCB");
    imageLabel->setText("Camera preview area");
}

void MainWindow::loadResultText(const QString &path) {
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        statusLabel->setText("Waiting for detection result");
        return;
    }
    QStringList lines;
    QTextStream in(&file);
    while (!in.atEnd()) {
        lines << in.readLine();
    }
    if (lines.size() < 4) {
        statusLabel->setText("Invalid result format");
        return;
    }
    statusLabel->setText(lines[0] == "YES" ? "Defect detected" : "No defect");
    summaryLabel->setText(QString("Count: %1\nInfo: %2\nTime: %3").arg(lines[1], lines[2], lines[3]));
}

void MainWindow::loadResultImage(const QString &path) {
    QPixmap pixmap(path);
    if (pixmap.isNull()) {
        imageLabel->setText("No result image");
        return;
    }
    imageLabel->setPixmap(pixmap.scaled(imageLabel->size(), Qt::KeepAspectRatio, Qt::SmoothTransformation));
}
