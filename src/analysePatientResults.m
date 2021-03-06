function table = analysePatientResults(results, make_hists, print_table, confidence, bins)
%table = analysePatientResults(results [, make_hists, print_table, confidence, bins])
%
% Analyses the results produced by processPatients(). Will produce histograms
% and result tables containing means, standard deviations and confidence
% intervals.
%
%Parameters:
%
% results - The data structure produced by the function processPatients().
%
% make_hists - Boolean flag indicating if monitoring histograms should be
%              produced of the data samples (i.e. the uncertainty distribution).
%              These will be written to EPS files. Default = 1 (true)
%
% print_table - Boolean flag indicating if the output table should be printed.
%               Default = 1 (true)
%
% confidence - The confidence interval (CI) to use. Default = 0.95
%
% bins - Scalar indicating the number of bins to use or vector indicating bin
%        ranges as passed to this hist() function. Default = 10
%
% The returned table will be a Nx5 cell matrix with the columns holding the
% following fields (i.e table{:,n}):
%   n = 1 - The calculation type as a string.
%   n = 2 - The source DVH file name as a string. Only valid for per patient
%           calculations. Boot-strapped calculations will have an empty string.
%   n = 3 - The organ name as a string.
%   n = 4 - The response model name as a string.
%   n = 5 - A vector with the following statistics for the sample distribution:
%           [min, max, lower CI, upper CI, mean, median, std.dev.]

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%    Particle Therapy Project Bergen (PTPB) - tools and models for research in
%    cancer therapy using particle beams.
%
%    Copyright (C) 2015 Particle Therapy Group Bergen
%
%    This program is free software: you can redistribute it and/or modify
%    it under the terms of the GNU General Public License as published by
%    the Free Software Foundation, either version 3 of the License, or
%    (at your option) any later version.
%
%    This program is distributed in the hope that it will be useful,
%    but WITHOUT ANY WARRANTY; without even the implied warranty of
%    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%    GNU General Public License for more details.
%
%    You should have received a copy of the GNU General Public License
%    along with this program.  If not, see <http://www.gnu.org/licenses/>.
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Author: Artur Szostak <artursz@iafrica.com>

if nargin == 0
    % Print help message if no arguments are given.
    help analysePatientResults;
    return;
end

if ~ exist('make_hists')
    make_hists = 1;
end
if ~ exist('print_table')
    print_table = 1;
end
if ~ exist('confidence')
    confidence = 0.95;
end
if ~ exist('bins')
    bins = 10;
end

% Calculate the lower and upper quantiles to calculate for the confidence
% interval requested.
ci_diff = (1 - confidence) * 0.5;
qlow = ci_diff;
qhigh = 1 - ci_diff;

% Go through the results data and calculate the statistics for all the sample
% distributions. Collect these statistics into the output table and finally
% print the table if so requested.
table = {};
row = 1;
fields = fieldnames(results);
for n = 1:length(fields)
    field = fields{n};
    if iscell(results.(field))
        for m = 1:length(results.(field))
            [organs, models, stats] = analyseOrgansAndModels(
                                        results.(field){m}.organs, qlow, qhigh,
                                        make_hists, field, m, bins);
            for k = 1:length(organs)
                table{row,1} = field;
                table{row,2} = results.(field){m}.filename;
                table{row,3} = organs{k};
                table{row,4} = models{k};
                table{row,5} = stats{k};
                row += 1;
            end
        end
    else
        [organs, models, stats] = calcOrganAndModelAverages(
                                                results.(field), qlow, qhigh,
                                                make_hists, field, bins);
        for k = 1:length(organs)
            table{row,1} = field;
            table{row,2} = '';
            table{row,3} = organs{k};
            table{row,4} = models{k};
            table{row,5} = stats{k};
            row += 1;
        end
    end
end
if print_table
    printTable(table);
end
return;


function [organs, models, stats] = analyseOrgansAndModels(
                            data, qlow, qhigh, make_hists, field, patient, bins)
% This function calculates the sample distribution statistics on a per patient
% basis for all organs and models. Will produce an EPS histogram of this
% distribution if so requested.
organs = {};
models = {};
stats = {};
k = 1;
organ_names = fieldnames(data);
for n = 1:length(organ_names)
    organ = organ_names{n};
    model_names = fieldnames(data.(organ));
    for m = 1:length(model_names)
        model = model_names{m};
        organs{k} = organ;
        models{k} = model;
        stats{k} = estimateStats(data.(organ).(model), qlow, qhigh);
        if make_hists
            hist(data.(organ).(model), bins);
            title(sprintf('Uncertainty distribution for %s, patient %d, %s, %s',
                          strrep(field, '_', '\_'), patient,
                          strrep(organ, '_', '\_'), strrep(model, '_', '\_')));
            print('-landscape', '-deps2', '-color',
                  sprintf('%s-patient%d-%s-%s.eps', field, patient, organ, model));
        end
        k += 1;
    end
end
return;


function [organs, models, stats] = calcOrganAndModelAverages(
                                    data, qlow, qhigh, make_hists, field, bins)
% This function calculates the distribution statistics for the averages of
% boot-strapped sample data. Will produce and EPS of the uncertainty distribution.
organs = {};
models = {};
stats = {};
k = 1;
organ_names = fieldnames(data);
for n = 1:length(organ_names)
    organ = organ_names{n};
    model_names = fieldnames(data.(organ));
    for m = 1:length(model_names)
        model = model_names{m};
        organs{k} = organ;
        models{k} = model;
        [nr, nc] = size(data.(organ).(model));
        if nr > 1
            samples = mean(data.(organ).(model))';
        else
            samples = data.(organ).(model)';
        end
        stats{k} = estimateStats(samples, qlow, qhigh);
        if make_hists
            hist(samples, bins);
            title(sprintf('Uncertainty distribution for %s, %s, %s',
                          strrep(field, '_', '\_'), strrep(organ, '_', '\_'),
                          strrep(model, '_', '\_')));
            print('-landscape', '-deps2', '-color',
                  sprintf('%s-%s-%s.eps', field, organ, model));
        end
        k += 1;
    end
end
return;


function y = estimateStats(x, lower_quantile, upper_quantile)
% Estimates the statistical parameters of a distribution of samples 'x'.
q = quantile(x, [lower_quantile, upper_quantile], 1, 8);
y = [min(x), max(x), q', mean(x), median(x), std(x)];
return;


function printTable(table)
% Prints the output table to the console.
[nr, nc] = size(table);
maxtype = max(cellfun('length', {table{:,1}}));
maxfilename = max(cellfun('length', {table{:,2}}));
maxorgan = max(cellfun('length', {table{:,3}}));
maxmodel = max(cellfun('length', {table{:,4}}));
printf('%*s\t%*s\t%*s\t%*s\t%12s\t%12s\t%12s\t%12s\t%12s\t%12s\t%12s\n',
       maxtype, 'Type', maxfilename, 'Filename', maxorgan, 'Organ',
       maxmodel, 'Model', 'Min', 'Max', 'CI low', 'CI high', 'Mean',
       'Median', 'Std.Dev.');
for n = 1:nr
    stats = table{n,5};
    printf('%*s\t%*s\t%*s\t%*s\t%e\t%e\t%e\t%e\t%e\t%e\t%e\n',
           maxtype, table{n,1}, maxfilename, table{n,2}, maxorgan, table{n,3},
           maxmodel, table{n,4}, stats(1), stats(2), stats(3), stats(4),
           stats(5), stats(6), stats(7));
end
return;
