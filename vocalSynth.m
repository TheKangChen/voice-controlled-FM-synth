function vocalSynth()

%--------------------------------------------------------------------------
% Control FM Synthesizer with Sound
%--------------------------------------------------------------------------
% DESCRIPTION:
% Detect RMS & Pitch of the input audio to control syth parameters:
% RMS --> Carrier amplitude, modulator amplitude, modulator frequency
% Pitch --> Carrier Frequency, modulator frequency
% CKChen 2021, NYU

clc
clear
close all
clear sound


%--------------------------------------------------------------------------
% Set Audio I/O
%--------------------------------------------------------------------------
% !! Please Set audio device in line 29 to the correct one currently using
% if the default option does not work.

deviceReader = audioDeviceReader;
deviceWriter = audioDeviceWriter;

fs = deviceReader.SampleRate;
bufferSz = deviceReader.SamplesPerFrame;
%devices = getAudioDevices(deviceWriter);
%devices;
%deviceReader.Device = " (2- CalDigit Thunderbolt 3 Audio)";
deviceReader.Device = "Default";
deviceWriter.SampleRate = fs;


% GUI
fig = [];
btn = [];
plotRMS = [];
textPitch = [];
plotProcessed = [];
audioRMS = [];
audioPE = [];


createGUI()

%--------------------------------------------------------------------------
% Functions
%--------------------------------------------------------------------------
    function createGUI()
        
        fig = figure('Name','Voice Controlled FM Synthesizer',...
                     'Position',[500 200 1080 720]);
        btn = uicontrol('String','Start',...
                        'Style','togglebutton',...
                        'Callback',@startAudio,...
                        'Position',[360 20 360 20]);
        
        subplot(2,1,1);
        plotRMS = plot(zeros(1,bufferSz),'r');
        xlim([0 bufferSz]); ylim([-1 1]);
        ylabel('RMS');
        title('RMS & Pitch Analysis');
        textPitch = text(540,0,'- Hz',...
                         'HorizontalAlignment','center',...
                         'VerticalAlignment','middle',...
                         'FontSize',50,...
                         'Color','k');
        
        subplot(2,1,2);
        plotProcessed = plot(zeros(1,bufferSz),'b');
        xlim([0 bufferSz]); ylim([-1 1]);
        ylabel('Magnitude');
        title('FM Synthesis');
    end

    function startAudio(h,~)
        
        btn.String = 'Stop';
        
        while true
            try
                audioIn = deviceReader();
                audioProcessed = processing(audioIn);
                            
                if ~btn.Value
                    break;
                end
                
                plotRMS.YData = audioRMS;
                textPitch.String = [sprintf('%.2f',audioPE),' Hz'];
                plotProcessed.YData = audioProcessed;
                
                deviceWriter(audioProcessed);
                drawnow
            catch
                break;
            end
        end
        
        stopAudio();
    end

    function stopAudio(h,~)
        try
            btn.Value = 0;
            btn.String = 'Start';
            
            release(deviceReader);
            release(deviceWriter);
        catch
        end
    end

    function processedOutput = processing(signal)
        audioRMS = movingRMS(signal);
        audioPE = pitchEstimation(signal);
        processedOutput = fmSynth(audioPE,audioRMS,bufferSz);
    end

    function rmsOutput = movingRMS(signal)
        movRMS = dsp.MovingRMS;
        rmsOutput = movRMS(signal);
    end

    function f0 = pitchEstimation(signal)
        winLength = length(signal);
        overlapLength = 0;
        [f0,~] = pitch(signal,fs,'WindowLength',winLength,'OverlapLength',overlapLength);
    end

    function [fmOutput] = fmSynth(freqVector,ampVector,duration)
        % Gate noise floor lower than 0.01 RMS
        if ampVector < 0.01
            ampVector = 0;
        end
        
        % Carrier Amplitude & Frequency
        ac = mean(ampVector) * 20;
        fc = freqVector;
        
        % Modulator Amplitude & Frequency
        am = ac / 20;
        fm = ac * fc / (fs / 2) * 2;
        
        y = zeros(duration,1);
        
        for i=1:(duration-1)
            y(i) = ac * cos(2 * pi * fc * i/fs + am/fm * sin(2 * pi * fm * i/fs));
        end
        
        win = hamming(duration);
        y = y .* win; % Limit harsh noise created by level difference
        
        fmOutput = y;
    end
end