%this script performs a simple CPMG experiment (with phase cycling) with multiple excitation pulse
%amplitudes, and measures the resulting magnetization from each. By looking
%for maximums and zeros in the results, the 90 and 180 degree flip angle
%amplitudes can be found

global experiment;  %define globals
global true_experiment;
declare_experiment;
global s;

define_experiment_example; %define sequence parameters, this is a function you create

Npoints=8;  %number of different RF amplitudes to try
BW=100000; %bandwidth of amplitude measurement, should be equal to RF pulse bandwidth
experiment.Nsequences=uint16(Npoints);
experiment.Nexperiments=uint32(4);  %number of experiment repetitions

%define range of RF amplitude Vrf.  Range must be between 1 and 4095
Vrf_min=700;    
Vrf_max=1700;

%interpolate this range to get set of amplitudes to use
if Npoints>1
Vrf_series=[Vrf_min: (Vrf_max-Vrf_min)/(Npoints-1) : Vrf_max];
else
    Vrf_series=Vrf_min;
end
clear Vrf_min;
clear Vrf_max;

refocus_Vrf=2700;   %choose an approximate Vrf for the refocusing pulses.

%add these values into the experiment, and set RF phase at 0
for k=1:Npoints
    experiment.sequence(k).preppulse(1).Vb=uint16(Vrf_series(k));
    experiment.sequence(k).cpmg.Vb=uint16(refocus_Vrf);
    experiment.sequence(k).preppulse(1).pulsephase=single(0);
end

CPXechoes_pos=run_host_mode;  %perform experiment again with RF phase of 0

%change RF phase to 180 for phase cycling
for k=1:Npoints
    experiment.sequence(k).preppulse(1).pulsephase=single(180);
end

CPXechoes_neg=run_host_mode; %perform experiment again with RF phase of 180

%get mean real echo values
CPXechoes_sum=CPXechoes_pos-CPXechoes_neg; %take difference of echoes
CPXechoes_sum_mean=squeeze(mean(CPXechoes_sum,1)); %average all experiments
echovalues_f_mean=squeeze(evaluate_echoes_f_real_mean(CPXechoes_sum_mean,BW,100)); %calculate real echo values

%calculate time axis
time=[true_experiment.sequence(1).cpmg.tau*2:true_experiment.sequence(1).cpmg.tau*2:true_experiment.sequence(1).cpmg.tau*2*double(true_experiment.sequence(1).cpmg.Nechos)]./1000000;

%variable to hold all fitting results
fitparameters=zeros(Npoints,3);

%do exponential fit of real echo values
%should estimate approximate T2 and offset for best results.
%amplitude of first echo will be automatically used to guess intial
%magnetization

guessT2=0.005;
guessoffset=25;

%do three parameter exponential fits on data
for i=1:Npoints
   figure(i);
   fitparameters(i,:)=fminsearch('fitt2offset',[guessoffset echovalues_f_mean(i,1)-guessoffset guessT2],[],time,echovalues_f_mean(i,:));
end

%plot resulting magnetization vs Vrf
figure(9)
plot(Vrf_series,fitparameters(:,2))

% eval(['save data_flipcal_saved CPXechoes Vb_series fitparameters time experiment true_experiment'])