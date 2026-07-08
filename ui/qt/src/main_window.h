#pragma once

#include <QLabel>
#include <QMainWindow>
#include <QPushButton>
#include <QTimer>

class MainWindow : public QMainWindow {
    Q_OBJECT

public:
    explicit MainWindow(QWidget *parent = nullptr);

private slots:
    void refreshResult();
    void continueInspection();

private:
    QLabel *statusLabel;
    QLabel *summaryLabel;
    QLabel *imageLabel;
    QPushButton *refreshButton;
    QPushButton *continueButton;
    QTimer refreshTimer;

    void buildUi();
    void loadResultText(const QString &path);
    void loadResultImage(const QString &path);
};
